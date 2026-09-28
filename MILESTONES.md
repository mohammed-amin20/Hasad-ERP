# Hasad ERP — Milestones

Architecture source of truth for this project. Phase status, what each phase
delivered, and the handoff notes the next phase needs.

> **On location:** this file lives inside the repository (and is therefore
> versioned and pushed with the code). An earlier `MILESTONES.md` at
> `hasad/MILESTONES.md` — one directory *outside* the repo — was a 3-byte file
> containing nothing but a UTF-8 BOM, so no milestone history existed anywhere
> in version control. This file supersedes it. `AGENTS.md` points here.

`PROJECT_SPEC.md` is never edited by the docs ritual; real divergences are
logged in Appendix A instead.

---

## Phase map

| Phase | Scope | Status |
|---|---|---|
| **M13 Phase 0** | Offline cold start — a signed-in user survives a restart with no network | ✅ Complete |
| **M13 Phase 1A** | Offline *sales* write path — queue, replay, server idempotency, sign-out wipe | ✅ Complete |
| **M13 Phase 1A.1** | Invoice rows show their sync state; lists refresh after a drain | ✅ Complete |
| **M13 Phase 1B** | Offline writes for the remaining domains (payments, products, customers, suppliers, employees, journal, salaries) | ⏳ In progress — **payments + purchases slices done**, remaining domains pending |
| M13 Phase 2+ | — | ⏳ Not started |

---

## ✅ M13 Phase 0 — Offline cold start

**Problem.** "Kill the app while offline, restart it, and the user lands on the
login screen even though the data is still on the device."

**Root cause was a stream defect, not a caching one.** `SupabaseAuthRepository
.authStateChanges` used `.asyncMap((user) => user == null ? null :
_profileFor(user))`, and `asyncMap` forwards a throw as a *stream error, which
terminates the stream*. One offline profile read (the `users` table plus the
`get_user_tenants` RPC) therefore latched `authStateProvider` into `error` for
the whole process lifetime, and `app.dart` fell into `error: (_, _) =>
LoginScreen()`. Caching the profile alone would not have fixed it — the error
still killed the stream.

**Delivered**

- `lib/data/auth/offline_aware_auth_repository.dart` — decorator over the domain
  `AuthRepository`. Emits the cached profile *before* subscribing to the live
  stream, refreshes the cache on a live read, and on `NetworkException` keeps the
  cache and **ends the stream normally** (a `StreamProvider` retains its last
  value on completion, so the shell stays mounted). Only `NetworkException` is
  swallowed — a `ValidationException` (revoked session) still propagates, so a
  genuine auth failure is never masked by a stale cache.
- Security boundary preserved: a live `null` (sign-out) passes through and
  **drops** the cache. `signOut()` deletes the profile *before* calling the inner
  repository, so a device the user believes is signed out holds no offline
  access even if the SDK call fails. No TTL — the cache lives exactly as long as
  the SDK's own persisted session.
- Drift schema **2 → 3**: additive `local_user_profiles` table
  (`authUid` PK, `payload` JSON, `updatedAt`). No Supabase-side change, so no
  migration to apply.
- `authRepositoryProvider` became a `FutureProvider` (it awaits the store so the
  decorator can be constructed) — so **every read/write call site must
  `await ref.read(authRepositoryProvider.future)`**.
- `app.dart` returns `SplashScreen` until `localStoreProvider` resolves, so the
  shell never crashes on the null store during DB open.
- `NoWorkspaceView` — full-body empty state for a signed-in user with no tenant
  (`!AppUser.hasTenant`), routed from `app.dart` instead of the shell.
- A `StreamProvider` that closes without a value stays `AsyncLoading` forever,
  which had left the app on the splash screen indefinitely. The decorator now
  emits `null` when it ends having emitted nothing, because "nothing cached and
  nothing reachable" *is* the signed-out state.

**Tests:** +30 (432 → **462**). Includes a **file-backed restart durability**
case — closes the DB, drops the object, reopens over the same file, because
`NativeDatabase.memory()` cannot prove cross-process survival.

---

## ✅ M13 Phase 1A — Offline sales write path

**Scope was deliberately narrow: Sales Invoice only.** No other CRUD domain, and
no server call is allowed to be a second source of truth for a write.

**Problem it solved.** An offline-created invoice used to vanish: the write
needed the network, and there was no queue to fall back to.

**Delivered**

- `OfflineAwareSaleRepository.create()` calls `OfflineWriteCoordinator
  .writeSale()` directly. The old shape (try server → catch `NetworkException`
  → queue) is gone from the wrapper.
- **One transaction or nothing.** `LocalStore.transaction<T>()` is
  `_db.transaction(() => action(this))` — drift propagates the ambient zone, so
  the callback's statements join the transaction with no wrapper object. Invoice
  + lines + product stock + commission dues + journal + the queue leg all commit
  together; a throw in `enqueue` rolls the invoice back rather than leaving an
  invoice with no way to reach the server.
- **Dependency-aware replay.** `sync_queue.depends_on` is a JSON array of
  specific queue-item UUIDs (drift schema **4**). `SyncFlushSummary` gained
  `blocked` (deferred, not failed). `offline_sync.dart` re-scans until the whole
  graph drains **within one flush**. A `pending` prerequisite defers; a
  `failed`/`missing`/self-reference parks; a dependency belonging to another
  tenant is treated as missing, never crossed.
- **Background refresh must never destroy pending local work.** Master mirrors
  were `delete(tenant) + insert(snapshot)`, so a refresh landing between an
  offline create and its replay deleted the user's record. They now go through
  `_mirrorPreservingUnsynced`: `synced: false` rows are never deleted or
  overwritten, `synced: true` rows are replaced, and an incoming row whose id
  matches a preserved row is skipped so an offline edit is not reverted.
- **Drift schema 5 — `id_mappings` is tenant-scoped** (`tenant_id` added to the
  primary key `{tenantId, entity, localId}`). Before this it had no tenant column
  at all, so no sign-out could ever clear it. The migration is a table rebuild:
  `Migrator.deleteTable` takes a **String** table name and `Migrator` has no
  `batch` — use `m.database.batch(...)`.
- **Server idempotency — `supabase/migrations/0025_rpc_idempotency_offline.sql`**
  (applied by hand in the SQL Editor; regression `supabase/tests/0025_idempotency.ps1`).
  `0014` assumed idempotency was unneeded because "the UI disables double-submit"
  — that assumption dies with a queue, since a request that times out *after*
  commit is indistinguishable from one that never arrived. `adjust_inventory`
  (delta recomputed from the current qty, so a replay moves stock again) and
  `create_account` (a replay returned `{'duplicate': true}`, which the app
  surfaced as «كود الحساب مستخدم مسبقاً» and never learned the account id) now
  take a trailing `p_request_id uuid default null` and return the **stored**
  envelope on a replay.
- **Replay response resolver** — `resolveServerId` / `nestedReplayRow`
  (`offline_sync.dart`). A write RPC answers in one of **two** response families:
  a fresh write returns a *flat* envelope keyed by an entity-specific id
  (`invoice_id` / `payment_id` / `movement_id` / `salary_id` / `entry_id`); an
  idempotent replay returns `{'duplicate': true, '<entity>': {...}}`, nesting the
  row one level down where the id sits under the **table column name** — `id` for
  invoices/payments/movements/salaries but **`entry_id`** for journal entries.
  A miss returns null, `markReplaySynced` falls back to the local uuid, the
  `serverId != localId` guard skips `putMapping`, the row is *still* marked
  synced — so the mirror keeps a client uuid the server never issued and
  **nothing reports an error**. `settle_supplier` is exempt (it enqueues with
  `localId: null`).
- **`clearTenant` is wired to sign-out** (decision: signing out wipes the
  workspace's local data). `signOutAndWipeLocalData` shows the existing confirm
  dialog only when `pendingCount > 0`, and **sign-out always succeeds** — the
  wipe runs in its own scope so a `clearTenant` throw cannot skip the sign-out.

**Tests:** +37 to **499**, then the replay resolver added +14 → **513**.

---

## ✅ M13 Phase 1A.1 — Invoice sync state + post-drain refresh

**Problem.** Nothing in `presentation/` ever read the sync state that Phase 1A
had been recording, so an offline-created invoice looked exactly like a real one.

**Root cause.** The state existed and was discarded at the domain boundary:
`OfflineInvoiceRepository._localDrafts()` selects exactly the `synced == false`
mirror rows and `_rowToInvoice` mapped each to a domain `Invoice` **dropping
the flag**.

**Delivered**

- `lib/domain/invoices/invoice_sync.dart` — `InvoiceSyncState` +
  `fromQueueStatus`. The default branch is **`synced`, never `pending`**: absence
  of a leg is exactly what "already on the server" looks like, so an unknown
  future status degrading to the alarming state would badge every row after an
  upgrade.
- `LocalStore.queueLegsFor(tenantId, {entity})` — needed because `pendingSync`
  returns only `status = 'pending'` and so cannot distinguish "synced" from
  "failed", while `queueStatuses` keys by *leg* id rather than the local invoice
  id. Tenant isolation is part of the contract, not decoration.
- `invoiceSyncStatesProvider` (`Map<localInvoiceId, InvoiceSyncState>`) feeding
  the shared `InvoiceListView`, so **one change covers both Sales and Purchases**.
- **Absence of a badge means synced** (product decision). Only `pending` and
  `failed` render; a fully-synced row gains no extra width. Every state is a text
  badge, so the indicator never depends on colour alone.
- `Invoice` is deliberately **not** given a `syncState` field — it is live view
  state, and `Invoice.fromJson` parses the JSON cache where no such key exists.
- **A drain now invalidates the invoice lists, not just the badge.** Only
  `pendingSyncCountProvider` was invalidated, so after a successful sync the row
  kept the **local placeholder number** even though `markReplaySynced` had written
  the official one. `_refreshAfterDrain` now invalidates the badge **and**
  `saleInvoicesListProvider` / `purchaseInvoicesListProvider` in both flush paths
  (manual + auto-reconnect). Refresh trigger only — no business logic changed.
- The status cell uses `Wrap`, not `Row`. Measured with `Row`: **125px overflow
  at 768** and **74px at 375** for an unsynced consignment invoice (three badges
  in a `flex: 2` cell). Both viewports are pinned by tests.
- `syncing` exists in the enum but is **never rendered** — no flusher writes that
  status, and `autoSyncRunnerProvider` returns a stable instance so watching its
  mutable `isRunning` would not rebuild. Producing it honestly means persisting
  the state inside the flusher, i.e. changing the sync logic.

**Tests:** +28 → **541/541**. Mutation-proven three ways (`Wrap`→`Row`, dropping
the list invalidations, dropping the badge invalidation), each failing a
different assertion.

---

## Real-device verification (2026-09-28)

Phase 0 and Phase 1A passed verification on a physical Android device.

**Verified — sale invoice path only**

- Created a sale invoice with no network. It saved, appeared in the list, and was
  marked as an offline draft.
- Restoring connectivity drained the queue automatically and the invoice reached
  the server.

**Not exercised, and therefore still unconfirmed**

- `0025_rpc_idempotency_offline.sql`'s two RPCs — `adjust_inventory` and
  `create_account`. The sale path is independently protected by migration
  `0007`, so a verified sale does **not** validate `0025`. Live RPC signatures
  were never introspected either: `GET /rest/v1/` returns `401` for both the
  publishable key and an authenticated owner JWT. `0025` is **applied but
  unconfirmed**.
- The **lost-response replay** path (server committed, response never arrived).
  A clean reconnect cannot produce it; it needs an induced mid-flight failure.
- Phase 1A.1's badge has automated evidence only (layout structure + state
  transitions, mutation-proven). Visual confirmation with the real Cairo font is
  a human step.

---

## ✅ M13 Phase 1B — payments slice (offline payment write path)

**Delivered as the first slice of Phase 1B.** Payments are now local-first, in
line with Phase 1A's sales path: record and settle queue a replay leg and only
hit the server when the flusher drains.

**Delivered**

- `lib/data/payments/offline_aware_payment_repository.dart` — decorator over the
  abstract `PaymentRepository`. `record` delegates to
  `OfflineWriteCoordinator.recordPayment`, `settle` to `settleSupplier`; both live
  in the queue/local-mirror path. No connectivity hint (Phase 1A rule: never
  gate a write on the verdict).
- `paymentRepositoryProvider` (`payments_providers.dart`) rewired to Phase 1A's
  sales pattern: with a local store + tenant it returns the offline-aware
  wrapper (injecting `() => ref.read(accountRepositoryProvider).chart()` as the
  chart-seed closure), otherwise it falls back to the live `SupabasePaymentRepository`
  — so the web/no-store build keeps a working payment path.
- `recordPayment` / `settleSupplier` in `offline_write.dart` now run **inside one
  `LocalStore.transaction`** (the same primitive Phase 1A proved): invoice
  upserts, payment upsert, journal mirror (`_mirrorJournal(store: tx)`) and the
  queue leg all commit together — a throw in `enqueue` rolls the payment back.
- **Dependency-aware replay for payments.** `_enqueueRpc` gained optional
  `dependsOn` (JSON only when non-empty) and `store` (same store as the ambient
  transaction). `recordPayment` depends on the pending `create_sale_invoice`
  leg; `settleSupplier` depends on every pending parent it allocates against
  (owning purchase invoices via `a.invoiceId`, commission dues via the
  due→invoice map). The flush service already re-scans until a graph drains
  (Phase 1A), so a payment queued before its invoice still replays in order.
- `_refreshAfterDrain` (`offline_sync_providers.dart`) now also invalidates
  `customerDebtsProvider` + `supplierDebtsProvider`, so paying off a debtor /
  settling a supplier refreshes the debts screens in both flush paths.
- Server idempotency for payments is **already in place — no new migration**
  (deviation from the "verify every new RPC" handoff item): `record_payment`
  dedupes on `payments.request_id` and `settle_supplier` on
  `processed_requests` since migration `0009`, and both drafts already carry
  `p_request_id`. Verified by the existing flush tests, not by relying on 0009
  alone.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub` **555/555**
  (541 + 7 new payments tests + 6 new write/flush tests); `flutter build web
  --dart-define=use_arabic=true` green; `flutter build apk --debug` green.

**Sync badge for payments deliberately NOT delivered** — the discard-at-the-
boundary gap (`_rowToInvoice` dropping the state) is one provider per domain via
`queueLegsFor(entity:)`; payments join it only when the badge is wanted
app-wide, per the Phase 1A.1 scope and user decision.

**Still open for later Phase 1B slices:** customers, suppliers, employees,
journal entries, salaries, products each need their own offline write routing
(this slice covers payments only; the purchases slice follows).

---

## ✅ M13 Phase 1B — purchases slice (offline purchase write path)

**Delivered as the second slice of Phase 1B.** Purchases are now local-first,
copying the payments/sales pattern: a purchase invoice and its inline new
products enqueue replay legs and only hit the server when the flusher drains.

**Delivered**

- `lib/data/purchases/offline_aware_purchase_repository.dart` — decorator over
  the abstract `PurchaseRepository`; `create` delegates to
  `OfflineWriteCoordinator.createPurchaseInvoice`. `purchaseRepositoryProvider`
  (`purchases_providers.dart`) returns the offline wrapper when a local store +
  tenant are present, otherwise falls back to `SupabasePurchaseRepository` — the
  same wiring shape as `sales_providers.dart` / `payments_providers.dart`.
- **Inline NEW products map by an explicit `product_id`, never `new_product`**
  (user-confirmed decision). `writePurchase` now generates one `legId` per inline
  product and enqueues **two** legs in one transaction: a `table:products`
  `table_crud` leg whose stored row `id` IS `legId`, plus the
  `create_purchase_invoice` RPC leg with `dependsOn: [legId]` and
  `p_items[0].product_id` equal to that same client uuid. The queue keeps the
  table_crud payload in the legacy `new_product` shape; the RPC never sees it.
- **The phantom-uuid `depends_on` bug this exposed, found and fixed.**
  `writePurchase` pre-generated `legId`, but `_enqueueWrite` minted its **own**
  row `id: _uuid.v4()` and reused `legId` only as `entityId` — so the purchase
  leg's `depends_on` referenced a uuid that never existed in `sync_queue`, and
  the flusher parked the purchase (flush F: synced 1 vs expected 2; the write
  test's `dependsOn` never equalled the product leg's stored id). `_enqueueWrite`
  gained an optional `String? id` (`id ?? _uuid.v4()`), and `writePurchase`
  passes `id: legId`. `DriftLocalStore.enqueue` inserts the row id as-is
  (`local_store.dart:785-787`), so the stored id now matches `depends_on`.
- **No new migration — `create_purchase_invoice` is already idempotent.** `0008`
  dedupes on `p_request_id` (the draft already carries `requestId`); `0017`'s
  trigger stamps `tenant_id` on the products mirror insert; `0018` relinks
  existing-product consignment receipts server-side. Zero SQL added.
- **`_refreshAfterDrain`'s full invalidation set** now also covers
  `supplierDebtsProvider`, `productsListProvider` and `inventoryProductsProvider`
  (on top of the badge, both invoice lists and `customerDebtsProvider`) in both
  flush paths. Verified by a badge drain test that overrides the three with
  counting providers and asserts their builds grow after a drain.
- **Pending-save message lives on the parent list.** `purchase_invoices_screen.dart`
  `_newInvoice` shows `'تم حفظ فاتورة الشراء محليًا وستتم مزامنتها عند عودة الاتصال'`
  when the form pops with `pending: true`, else `'تم إنشاء فاتورة الشراء رقم
  ${result.no}'`. Widget-test fact: the purchase form body is a `ListView`, so
  below-fold controls are not mounted at 800×600 — the test drives it at
  `Size(600, 1600)`.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub` **567/567**
  (555 + 3 repository tests + 1 widget message test + 1 drain-invalidation test +
  7 write/flush test cases); `flutter build web --dart-define=use_arabic=true`
  green; `flutter build apk --debug` green.

**Sync badge for purchases deliberately NOT delivered** — same decision as
payments: `queueLegsFor(entity:)` makes it one provider once the badge is wanted
app-wide.

---

## Handoff to Phase 1B

**Already exists and is reusable**

- `OfflineWriteCoordinator` owns all master CRUD; Phase 1B should route the
  remaining domains through it rather than adding a second write path.
- `LocalStore.transaction<T>()` — the one-transaction-or-nothing primitive, with
  rollback doubles in `test/data/offline/delegating_local_store.dart`.
- `LocalStore.queueLegsFor(tenantId, {entity})` already takes an `entity` filter,
  so a per-domain sync indicator is one provider each.
- `_mirrorPreservingUnsynced` already protects unsynced rows on **every** master
  mirror, so refresh-during-offline-edit is handled for all domains.
- `delegating_local_store.dart` makes store-level rollback/failure injection
  straightforward for new tests.

**Must be built fresh**

- Per-domain write wiring *not yet done*: customers, suppliers, employees,
  journal entries, salaries. (The **payments and purchases slices of Phase 1B
  are already delivered** — their exact transaction + dependency pattern is the
  template to copy.)
- The same discard-at-the-boundary gap exists for each of them — the mirror
  merge and `_rowToInvoice`-equivalent drop the `synced` flag, so each needs its
  own sync indicator if the badge is wanted app-wide.
- Server idempotency for any additional write RPC that is not already
  protected. `0025` covers only `adjust_inventory` and `create_account`; verify
  each new RPC for the "replay re-applies the effect" and "replay looks like a
  validation error" failure modes before shipping it. Payments needed no new
  migration — `0009` already dedupes `record_payment` (by `request_id`) and
  `settle_supplier` (by `processed_requests`); copy that verification style for
  the remaining domains.

**Carry-forward rules (do not regress these)**

- Never gate a write on the connectivity verdict — attempt the server first,
  fall back to the queue only on `NetworkException`.
- Never let a background refresh delete or revert unsynced local work.
- Every family added to a query needs `==`/`hashCode` if it is a family-provider
  argument.
- Sign-out must never be gated on the local-data wipe.

---

## Appendix A — Implementation Log

| Slice | Commit | DB objects | Tests | Deviations |
|---|---|---|---|---|
| Phase 0 — offline cold start | *(this checkpoint 1/3)* | drift `local_user_profiles` (schema 3) | 432 → 462 | `authRepositoryProvider` became a `FutureProvider`; call sites must `await .future` |
| Phase 1A — queued sales writes | *(this checkpoint 2/3)* | drift `depends_on` (4), `id_mappings.tenant_id` (5), migration `0025` | 462 → 499 → 513 | `0025` adds a parameter with a default, so it **must** `drop function` the old signature first or PostgREST fails with "not unique" |
| Phase 1A.1 — invoice sync badge | *(this checkpoint 3/3)* | none | 513 → 541 | Badge is text-only and absent when synced; `syncing` deliberately not rendered |
| Phase 1B — payments write path | *(this checkpoint 4/4)* | none (driver `depends_on` reuse) | 541 → 555 | Payment sync badge out of scope; no new migration — `0009` already makes both payment RPCs idempotent |
| Phase 1B — purchases write path | *(this checkpoint 5/5)* | none | 555 → 567 | Inline new products use `product_id` (client uuid), never `new_product`; `_enqueueWrite` gained `String? id` (fixes a phantom-`depends_on`); purchase sync badge out of scope; no new migration — `0008`/`0017`/`0018` already cover it |
