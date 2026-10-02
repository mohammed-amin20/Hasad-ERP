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
| **M13 Phase 1B** | Offline writes for the remaining domains (payments, products, customers, suppliers, employees, journal, salaries) | ✅ Complete |
| **M13 Phase 2** | Device-reliability issues (6 reported real-device bugs) — **P0: issue 6 done** (cold-start data blackout); **P1: issues 3/4/5 done**; **P1.1: settlement attribution done**; **P2: issues 1/2 done**; **P1.C: corrective slice done** (invoice mirror authority, double-submit, action-provider lifecycle) | ✅ Complete — **issue 4 awaits a physical-device trace** |

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

## ✅ M13 Phase 1B — journal entries slice (offline manual journal write path)

**Delivered as the third slice of Phase 1B.** Manual journal entries are now
local-first: the coordinator validates against the local chart, writes the entry
and queue leg in one transaction, and only hits the server when the flusher
drains. The journal list also merges locally-created entries so an offline entry
shows up immediately.

**Delivered**

- **`OfflineWriteCoordinator.createJournal` is live — it was dead code.**
  Previously `OfflineJournalRepository.createManual` delegated straight to
  Supabase (network-first), and the coordinator's `createJournal` sat unused
  with four defects: no transaction, an empty-string-account fallback that
  silently accepted unknown accounts, no `dependsOn`, and no `store:` binding on
  the enqueue. The rewrite validates the balanced/≥2-lines guard, **rejects any
  line whose account is missing from the local chart** with
  `'أحد حسابات القيد غير موجود في دليل الحسابات (${l.accountId})'`
  (a `ValidationException` — never a silent accept, never an empty code), and
  runs `_store.transaction(...)`: local entry insert + `create_journal_entry`
  queue leg with `dependsOn: accountLegs` (`_pendingLegIdsFor` over the entry's
  account legs, pre-transaction) + `store: tx`. It returns
  `JournalEntryResult(entryId, entryNo: 0, total: debitTotal, pending: true)`.
- **`OfflineJournalRepository.createManual` routes through the coordinator** when
  one is present (falls back to the inner repo otherwise); `entries()` merges
  **only unsynced `sourceType == 'manual'`** rows (never auto journals — those
  stay owned by their flows) via `_localDrafts()` + `_merged()` (range-filter,
  dedupe, newest-first), converting through `_rowToEntry`.
- **Wiring:** `journalRepository` (`journal_providers.dart`) builds the offline
  repo with an `OfflineWriteCoordinator(store, tenantId, () => ref.read(
  accountRepositoryProvider).chart())` when a store + tenant are present, else
  falls back to `SupabaseJournalRepository`.
- **`_refreshAfterDrain` invalidation set extended with the journal-derived
  providers:** `journalListProvider`, `ledgerStatementProvider`,
  `trialBalanceProvider`, `incomeStatementProvider`, `balanceSheetProvider`,
  `dashboardSummaryProvider` (journal/accounting scope only; party statements
  deliberately excluded). Verified by a third drain test that overrides all six
  with counting notifiers and asserts their builds grow after a real journal
  drain (the leg enforced a real `create_journal_entry` replay).
- **Pending-save message on the journal screen.** The manual-entry sheet pops and
  the list screen shows `'تم حفظ القيد محليًا وستتم مزامنته عند عودة الاتصال'`
  when the result is `pending`, else `'تم إضافة القيد رقم ${result.entryNo}'`.
- **No new migration — `create_journal_entry` (0019) is already idempotent.**
  It balances + resolves server-side and dedupes on `p_request_id`; the draft
  already carries `requestId`. Zero SQL added.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub` **585/585**
  (567 + 2 flush drain tests — one real-leg E2E, one duplicate-replay no-dup —
  + 8 repository tests incl. routing and the manual-only merge + 2 widget
  message tests + 6 write tests + 1 drain-invalidation test + the existing
  badge drain cases); `flutter build web --dart-define=use_arabic=true` green;
  `flutter build apk --debug` green.

**Sync badge for journal entries deliberately NOT delivered** — same decision as
payments/purchases: `queueLegsFor(entity: 'journal_entries')` is one provider
once the badge is wanted app-wide.

---

## ✅ M13 Phase 1B — salaries & employee movements slice (offline salary write path)

**Delivered as the fourth slice of Phase 1B.** `pay_salary` and
`add_employee_movement` are now local-first: the coordinator validates against
the local chart/employee mirror, persists the mirror + queue leg + mirrored
journal in **one drift transaction**, and returns a `pending` result
immediately. Reads stay live-first with local fallbacks and unsynced merges, so
an offline salary/movement shows up before it drains and survives restarts.

**Delivered**

- **`OfflineWriteCoordinator.paySalary` rewritten** (was network-first RPC):
  - **Local duplicate-month guard first**: any local salary row for the same
    employee+month (synced or not) → `ValidationException('تم صرف راتب هذا
    الشهر مسبقاً')` — never enqueue a leg guaranteed to replay as a duplicate.
    The server's own `salaries` rows are **not** mirrored by design, so the guard
    covers only what this device ever wrote (documented non-goal).
  - **Arabic account pre-validation** against the local chart for `2030` +
    `5030` + (`1010` cash | `1015` bank): missing code →
    `ValidationException('الحساب غير موجود في دليل الحسابات: $code')`. This
    kills the English `StateError` that `DoubleEntryEngine._getAccount` would
    otherwise leak on a never-online device (the balanced-journal loss falls to
    the `_guard` mapping that only translated it).
  - Local entitlement math (base − previous-month `max(base − paid, 0)` arrears,
    `in`/`out` movements) mirrors the `get_employee_entitlement` RPC; one
    `_store.transaction`: `upsertSalary` + `_mirrorJournal(store: tx)` + a
    `pay_salary` leg with `dependsOn: _pendingLegIdsFor([employee.id])` computed
    **before** the tx, enqueued with `store: tx`. Returns
    `SalaryResult(..., pending: true)` — a throw in the final `enqueue` rolls
    everything back (strategy proven by the earlier slices).
- **`OfflineWriteCoordinator.addMovement` rewritten** the same way: `dependsOn:`
  `_pendingLegIdsFor([employee.id, if (product != null) product.id])` resolved
  before the tx; one transaction of `upsertEmployeeMovement` +
  `_applyProducts(store: tx)` (stock deduction for `product` movements) + the
  `add_employee_movement` leg with `store: tx`; missing employee →
  `ValidationException('الموظف غير موجود محلياً')`.
- **`OfflineSalaryRepository`** (`lib/data/offline/offline_salary_repository.dart`)
  implements `SalaryRepository`: `addMovement`/`pay` route to the coordinator
  (fall back to the live RPCs when no coordinator — web/unauthenticated);
  `entitlement`/`employeeStatement` are live-first and fall back on
  `NetworkException` to local mirror math via the domain's `buildEmployeeStatement`;
  `salaryHistory` is live-first and **merges only `!synced`** local rows
  (base salary from the employee mirror, date from `createdAt`), newest-first, and
  serves local rows — else rethrows — on `NetworkException`.
- **Wiring:** `salaryRepository` (`salaries_providers.dart`) returns the offline
  repo with an `OfflineWriteCoordinator(store, tenantId, () => ref.read(
  accountRepositoryProvider).chart())` when a store + tenant are present, else
  falls back to `SupabaseSalaryRepository`.
- **`_refreshAfterDrain` invalidates `salaryHistoryProvider`** (both flush paths),
  so an offline-paid salary stops reading as a draft once the queue clears.
  `salaryRun`/`employeeStatement` families are refreshed by `SalaryActions` on
  write and cannot be drain-invalidated (deliberate).
- **Pending-save SnackBars on the salary sheets.** Movement:
  `'تم حفظ الحركة محليًا وستتم مزامنتها عند عودة الاتصال'`; pay:
  `'تم حفظ عملية الصرف محليًا وستتم مزامنتها عند عودة الاتصال'` — shown only
  when `result.pending`; online messages unchanged.
- **No new migration** — `add_employee_movement` and `pay_salary` (0010) already
  dedupe on `p_request_id`; both drafts already carry `requestId`. Zero SQL
  added (`0025`'s "verify each new RPC" pass: verified green in the flush tests).
- **Verification:** `flutter analyze` clean; `flutter test --no-pub` **611/611**
  (585 + 10 offline_write cases incl. Arabic account/missing-employee rejects and
  rollback through `_ThrowOnEnqueueStore` + 9 repository tests incl. file-backed
  restart persistence + 2 flush tests — dependency ordering after a pending
  employee leg and nested duplicate-replay no-dup — + 4 widget message tests + 1
  drain-invalidation test); `flutter build web --dart-define=use_arabic=true`
  green; `flutter build apk --debug` green.

**Sync badge for salaries/movements deliberately NOT delivered** — same decision
as payments/purchases/journal: `queueLegsFor(entity: 'salaries')` /
`entity: 'employee_movements'` are one provider each once the badge is wanted
app-wide.

---

## ✅ M13 Phase 1B — customers master CRUD write path (offline)

**Delivered as the fifth slice of Phase 1B.** Customer create/update/delete are
now local-first, copying the purchases/salaries transaction pattern.

- **`OfflineWriteCoordinator.writeCustomer/updateCustomer/deleteCustomer`** are
  each one `_store.transaction(...)`: the mirror upsert + a `table_crud` leg
  (`_enqueueWrite` already gained `dependsOn:`/`store:` in earlier slices) commit
  or roll back together. `updateCustomer` preserves `createdAt`; `deleteCustomer`
  validates the row exists (`ValidationException` otherwise), **keeps the mirror
  row** with `synced: false`, and enqueues a **delete-shape** leg
  (`params: {'id': id}` — no `row`) whose `dependsOn` references every *pending*
  same-id leg, so the delete never sorts before its own create/update.
- **Delete = server hard-delete, surfaced offline via two new `LocalStore`
  methods:**
  - `pendingDeleteIds(tenantId, entity)` — the set of local ids with a
    **`status == 'pending'` delete-shape leg** (`op == 'table_crud'`,
    `params` has `id` and **no** `row`). Reads hide exactly these rows.
  - `removeMirrorRows(tenantId, entity, ids)` — deletes the mirror rows after the
    flusher's `tableDelete` succeeds (customers/suppliers/products/employees;
    `NullLocalStore` is a no-op). `markReplaySynced` must NOT be reached for a
    delete — the flusher's delete branch returns before it, so the mirror row
    stays until the server confirms, and is then removed by `removeMirrorRows`.
  - **A FAILED delete relaxes the filter (requirement #9):** only *pending*
    deletes suppress. Once the leg is parked `failed` the mirror row reads again
    locally (`leg.attempts >= kSyncMaxAttempts = 5` parks it), and the reconnect
    flush retries it.
- **Fresh-vs-replay mapping for the delete leg is the `{'id': id}` shape, and
  the flusher recognizes it by `containsKey('id') && !containsKey('row')`.**
  An upsert leg's `row` key is what keeps the row showing until the flusher
  re-marks it synced.
- **`OfflineCustomerRepository`** (`lib/data/offline/offline_customer_repository.dart`)
  took an optional `coordinator:` + `writesAreLocalFirst` getter; `create`/
  `update`/`delete` route to the coordinator when present, else to the inner
  repo. Reads hide pending-delete ids in `_readAll`/getById. `customersRepository`
  (`customers_providers.dart`) builds it with a coordinator when store + tenant
  are present, else falls back to the Supabase repo.
- **The SnackBars branch on a new boolean `customerWritesLocalFirstProvider`**
  (codegen'd, overridable with `overrideWithValue(bool)`): create → `'تم حفظ
  العميل محليًا وستتم مزامنته عند عودة الاتصال'`, update → `'تم حفظ تعديلات
  العميل محليًا وستتم مزامنتها عند عودة الاتصال'`, delete → `'تم حذف العميل
  محليًا وستتم مزامنته مع الخادم عند عودة الاتصال'`. The FAB tooltip
  `'إضافة عميل'` triggers the same sheet as before.
- **No new migration:** master `table_crud` legs replay against
  `.from('customers')` directly (the `0017` trigger stamps `tenant_id`); there is
  no customer write RPC to make idempotent.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub`
  **634/634** (611 + 7 master-writes + 6 repository + 6 flush + 4 widget);
  `flutter build web --dart-define=use_arabic=true` green;
  `flutter build apk --debug` green.
- **Follow-up (later Phase 1B slices):** suppliers + employees master CRUD are
  the same lighter-weight pattern (their `table_crud` legs already exist) — the
  customers slice is the template. Customer sync badge still deferred (same
  `queueLegsFor(entity: 'customers')` approach as invoices).

---

## ✅ M13 Phase 1B — suppliers master CRUD write path (offline)

**Delivered as the sixth slice of Phase 1B.** Supplier create/update/delete are
now local-first, copying the customers slice (the transaction pattern + the
hard-delete surface) with two added readiness fixes and a **local FK rule** the
customers slice did not need.

- **`OfflineWriteCoordinator.writeSupplier/updateSupplier/deleteSupplier`** are
  each one `_store.transaction(...)`: the mirror upsert + a `table_crud` leg
  commit or roll back together. `updateSupplier` preserves the existing
  `createdAt` (read-then-upsert inside the tx) and adds a `dependsOn` on any
  pending same-id legs; `deleteSupplier` validates the row exists
  (`'المورد غير موجود محلياً'` otherwise), flips the kept row `synced: false`,
  and enqueues the delete-shape `{'id': id}` leg with `dependsOn` = pending
  same-id legs.
- **Two data bugs fixed while wiring the mirror (do not re-introduce):**
  `writeSupplier` dropped `commissionRate` — it is now mirrored AND returned on
  the `Supplier` the coordinator hands back; `updateSupplier` stamped a fresh
  `createdAt` — it now preserves the existing row's.
- **Delete = local FK rule (user-confirmed option 1 — "Reject if local refs
  exist").** The server has a hard FK (`products.supplier_id` NO ACTION +
  `commission_dues.supplier_id` NO ACTION), so a delete would fail server-side
  on any referenced supplier. Before queueing, `deleteSupplier` mirrors that
  FK using the local mirrors: if any `local_products.supplierId` OR any
  `local_commission_dues.supplierId` equals the id it throws
  `ValidationException('لا يمكن حذف المورد لأنه مرتبط بمنتجات أو عمولات موجودة')`
  and enqueues nothing. When no local reference exists the delete queues; if the
  **server** later rejects on a reference the local mirrors never saw (mirror is
  only as complete as the data synced to this device), the existing FAILED-delete
  behavior keeps the supplier visible locally and the next flush retries. That
  limitation is documented on `deleteSupplier` itself.
- **`OfflineSupplierRepository`** took an optional `coordinator:` +
  `writesAreLocalFirst` getter; `create`/`update`/`delete` route to the
  coordinator when present, else to the inner Supabase repo. Reads hide
  `pendingDeleteIds(t, 'suppliers')` in `_readAll`, so a pending delete
  disappears from the list and a FAILED delete brings the row back
  (requirement #9).
- **Provider wiring:** `supplierRepositoryProvider` builds the offline repo with
  a coordinator when store + tenant are present (else the Supabase repo), and a
  codegen'd boolean `supplierWritesLocalFirstProvider` drives the SnackBars:
  create → `'تم حفظ المورد محليًا وستتم مزامنته عند عودة الاتصال'`, update →
  `'تم حفظ تعديلات المورد محليًا وستتم مزامنتها عند عودة الاتصال'`, delete →
  `'تم حذف المورد محليًا وستتم مزامنته مع الخادم عند عودة الاتصال'`.
- **Ordering verified end to end:** a `writePurchase` referencing a created
  supplier depends on the supplier *leg*, and the flush replays the supplier
  before the purchase; the same holds for the `settle_supplier` leg (which added
  the `2010` account to the shared spike seed). Replayed supplier legs are
  idempotent on the mirror (upsert never duplicates, delete is a no-op when the
  row is gone).
- **No new migration:** master `table_crud` legs replay against
  `.from('suppliers')` directly (the `0017` trigger stamps `tenant_id`); `0025`
  is untouched.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub`
  **660/660** (634 + 9 master-writes + 6 repository + 7 flush + 4 widget);
  `flutter build web --dart-define=use_arabic=true` green;
  `flutter build apk --debug` green.
- **Follow-up:** only **employees** master CRUD remains for Phase 1B — the
  suppliers slice is the template. Supplier sync badge still deferred (same
  `queueLegsFor(entity: 'suppliers')` approach as invoices).

---

## ✅ M13 Phase 1B — employees master CRUD write path (offline)

**Delivered as the seventh slice of Phase 1B — the last Phase 1B domain, closing
the phase.** Employee create/update/delete are now local-first. Before this
slice, employee writes were *online-only*: `employees_providers.dart` wired
`OfflineEmployeeRepository` **without a coordinator**, and the coordinator's
`writeEmployee`/`updateEmployee`/`deleteEmployee` were stale Slice-C versions
(no transaction, no `dependsOn`, `updateEmployee` stamped a fresh `createdAt`,
`deleteEmployee` had no existence check / mirror-flip / FK rule).

- **`OfflineWriteCoordinator.writeEmployee/updateEmployee/deleteEmployee`**
  rewired to the same one-`_store.transaction(...)` pattern as suppliers:
  mirror upsert + `table_crud` leg commit or roll back together.
  `updateEmployee` preserves the existing row's `createdAt` (read-then-upsert
  via the new `_employeeRow(id)` helper next to `_supplierRow`) and adds a
  `dependsOn` on pending same-id legs. `deleteEmployee` validates the row
  exists (`'الموظف غير موجود محلياً'` — role-split wording, `'محلياً'` not
  `'محلّيًا'` for the user-facing screens), flips the kept row `synced: false`,
  and enqueues the delete-shape `{'id': id}` leg with `dependsOn` = pending
  same-id legs.
- **Delete = local FK rule (server-parity, audited rather than assumed).**
  `employees` is a **hard-delete** table (no soft/archive column in 0002) and
  every referencing FK is `ON DELETE NO ACTION`, so the server rejects a delete
  while referenced: `salaries.employee_id` and `employee_movements.employee_id`
  are NOT NULL; `stock_moves.employee_id` is nullable. `deleteSupplier`-
  style, `deleteEmployee` rejects before queueing with
  `ValidationException('لا يمكن حذف الموظف لأنه مرتبط برواتب أو حركات موجودة')`
  when any `local_salaries.employeeId` OR any `local_employee_movements
  .employeeId` equals the id, enqueuing nothing. `stock_moves` is **never
  mirrored** — a stock movement referencing the employee is the documented
  limitation: the server may still reject, and the existing FAILED-delete
  behavior keeps the row visible while the next flush retries (never silent
  data loss). Movement/salary legs were already dependency-ready:
  `addMovement`/`paySalary` call `_pendingLegIdsFor([employee.id])`, so a
  create→movement and create→salary series replay in order with zero extra
  wiring.
- **`OfflineEmployeeRepository`** gained an optional `coordinator:` +
  `writesAreLocalFirst` getter; `create`/`update`/`delete` route to the
  coordinator when present, else to the inner Supabase repo. Reads hide
  `pendingDeleteIds(t, 'employees')` in `_readAll`/getById-local, so a pending
  delete disappears from the list and a FAILED delete brings the row back
  (requirement #9). `getById` of a hidden id falls through `cacheFirst` to the
  unreachable network and rethrows `NetworkException` — parity with listAll,
  never a fabricated null.
- **Provider wiring:** `employeeRepository` (`employees_providers.dart`) builds
  the offline repo with a coordinator when `localStoreProvider.value` + tenant
  are present (else `SupabaseEmployeeRepository`), and a codegen'd boolean
  `employeeWritesLocalFirstProvider` drives the SnackBars (create
  `'تم حفظ الموظف محليًا وستتم مزامنته عند عودة الاتصال'`, update
  `'تم حفظ تعديلات الموظف محليًا وستتم مزامنتها عند عودة الاتصال'`, delete
  `'تم حذف الموظف محليًا وستتم مزامنته مع الخادم عند عودة الاتصال'` — the
  delete wording is suppliers-style pending, user-confirmed; the online
  originals `'تمت إضافة الموظف'`/`'تم تعديل الموظف'`/`'تم حذف الموظف'` are
  unchanged on the online path; the hard-delete confirm dialog `'حذف الموظف'`
  is untouched). `employees_providers.g.dart` regenerated (only
  employee-wired file in this slice; the stale
  `journal/payments/purchases_providers.g.dart` no-ops stay uncommitted).
- **No new migration:** master `table_crud` legs replay against
  `.from('employees')` directly (the `0017` trigger stamps `tenant_id`); `0025`
  untouched — no employee write RPC to make idempotent.
- **Verification:** `flutter analyze` clean; `flutter test --no-pub` **687/687**
  (660 + 9 master-writes + 7 repository + 7 flush + 4 widget);
  `flutter build web --dart-define=use_arabic=true` green;
  `flutter build apk --debug` green. **Phase 1B is complete.** Employee sync
  badge still deferred (same `queueLegsFor(entity: 'employees')` approach as
  invoices).

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

- **All Phase 1B domains are delivered** — payments, purchases, journal,
  salaries + employee movements, customers, suppliers, and employees master
  CRUD. Their exact transaction + dependency pattern (one `_store.transaction`,
  `dependsOn` on pending legs, `_enqueueWrite(id:)` for multi-leg writes) is the
  template for any future offline domain. The customers/suppliers/employees
  slices also ship the hard-delete surface: `pendingDeleteIds` suppresses
  reads, `removeMirrorRows` clears the mirror only after a confirmed
  `tableDelete`, a FAILED delete relaxes the filter, and the suppliers +
  employees slices add local-FK delete rules (reject while local mirrors
  reference the row; limitation documented when the server sees an unmirrored
  reference).
- The same discard-at-the-boundary gap exists for each of them — the mirror
  merge and `_rowToInvoice`-equivalent drop the `synced` flag, so each needs its
  own sync indicator if the badge is wanted app-wide.
- Server idempotency for any additional write RPC that is not already
  protected. `0025` covers only `adjust_inventory` and `create_account`; verify
  each new RPC for the "replay re-applies the effect" and "replay looks like a
  validation error" failure modes before shipping it. Payments needed no new
  migration — `0009` already dedupes `record_payment` (by `request_id`) and
  `settle_supplier` (by `processed_requests`); the salaries slice verified
  `0010`'s salary RPCs the same way (zero SQL); copy that verification style for
  the remaining domains.

**Carry-forward rules (do not regress these)**

- Never gate a write on the connectivity verdict — attempt the server first,
  fall back to the queue only on `NetworkException`.
- Never let a background refresh delete or revert unsynced local work.
- Every family added to a query needs `==`/`hashCode` if it is a family-provider
  argument.
- Sign-out must never be gated on the local-data wipe.

---

## Handoff to Phase 2 (device-reliability issues)

**Already exists and is reusable for the remaining 5 issues**

- The loud-failure gate (issue 6, P0): `openLocalStore` → `LocalStoreOpenException`
  + `app.dart` `store.hasError` branch → `LocalDataRepairScreen`. Any future
  "cold start looks empty" symptom now lands on the repair state, not a silent
  empty shell.
- The `LocalDataRepairScreen` reset/retry skeleton is the template for any
  device-facing error UI: `showConfirmDialog(..., tone: ConfirmTone.danger)`,
  injectable `resetLocalDatabaseProvider`, dispose-then-delete-then-invalidate.
- File-backed drift durability harness in `test/data/offline/` (open/close/
  reopen over a real sqlite file in a temp dir) is the pattern for reproducing
  restart bugs without a device.
- **Test-only fact to reuse:** `ProviderScope(retry: (_, _) => null)` disables
  Riverpod 3.4.3's default exponential-backoff auto-retry; production keeps it.

**Must be built fresh**

- ~~**P1 — issue 3 (payments mis-recorded when written offline and drained),
  issue 4 (employee-movement stock deduction/product-deduction paths vs the
  queue), issue 5 (salary double-pay guard vs the offline queue).**~~ **DONE —
  see "Handoff to Phase 2 P2" below.**
- **P2 — issue 1 (sale/purchase refresh invalidation), issue 2 (sync badge
  semantics).** Reuse `_refreshAfterDrain`'s invalidation set + `queueLegsFor`
  per-domain indicator pattern.
- Issue 4's instruction: test BOTH movement types (product-deduction and
  plain-advance) and ignore the contradictory AGENTS.md overflow test line.
- Issue 6's anti-pattern guard: never auto-delete the store on first failure.

**Carry-forward rules (do not regress these)**

- Never gate a write on the connectivity verdict — attempt the server first,
  fall back to the queue only on `NetworkException`.
- Never let a background refresh delete or revert unsynced local work.
- Every family added to a query needs `==`/`hashCode` if it is a family-provider
  argument.
- Sign-out must never be gated on the local-data wipe.

---

## Handoff to Phase 2 P2 (issues 1 and 2)

Phase 2 P1 (issues 3, 4, 5) is complete. Nothing here is started; P2 is next.

**What P2 reuses (do not rebuild)**

- **`LocalStore.resolveInvoiceMoneyMarker(tenantId, legId)`** (`local_store.dart`)
  plus the `local_invoices.pendingMoneyLeg` column (drift schema **6**) are the
  canonical "has a pending local money mutation" signal. It is a **leg id, not a
  boolean**, on purpose — a dirty-flag cannot express two overlapping payments on
  the same invoice. Anything that needs to know whether a money figure is local
  reads the marker rather than the queue.
- **The flusher retires a marker only when nothing else is outstanding for that
  invoice**, and otherwise re-stamps it to the oldest leg that has not landed
  (`offline_sync.dart`). Clearing on *this leg's* success alone is **not**
  sufficient and was a shipped bug: with two payments on one invoice draining out
  of order, the newer leg's success cleared the marker even though the older leg
  was still queued, handing the row back to a server figure that knew about
  neither. Failure paths deliberately leave the marker alone. The overlap
  invariant is mutation-proven in `offline_invoice_pending_money_test.dart`.
  **The settlement residual described in P1 is now closed** — see
  "Phase 2 P1.1" below; a `settle_supplier` leg is attributed by a persisted
  `affects_invoice_ids` set, not by its params.
- **`_withPendingMoney` in `offline_statement_repository.dart`** is the pattern
  for "a server aggregate does not know about a local write yet": subtract the
  unsynced `local_payments` for the party. Issue 1's sale/purchase refresh and
  issue 2's badge semantics both need the same reasoning, on different data.
- **`_refreshAfterDrain`'s invalidation set** (`offline_sync_providers.dart`) is
  already the full list of providers a drain invalidates — issue 1 is very
  likely a missing entry there, not new logic.
- **`SheetErrorBanner`** (`lib/presentation/widgets/sheet_error_banner.dart`) is
  the reusable inline-error surface. Sheets keep SnackBars for *success* only.

**Must be built fresh**

- Issue 1's invalidation set, and issue 2's badge rules, both need
  reproduce-first tests against the flusher before any code moves.
- Nothing in P1 required a Supabase migration or an RPC change; P2 should hold to
  the same Dart-only bar unless a reproduce proves otherwise.

**Carry-forward rules from P1 (do not regress these)**

- A mutation that is still queued must keep its local figures authoritative;
  clearing a marker too early hands the row back to a server value that knows
  about neither the mutation nor its absence. "This leg succeeded" is **not** the
  same as "every money leg for this invoice succeeded".
- A **read** on a missing drift column returns `null` rather than throwing, so a
  read-only assertion proves nothing about a migration. Write through the typed
  API to test one.
- `SyncFlusher` drains an entire dependency graph **within one pass** (it
  rescans), so two independent legs both sync in a single `flush()` — do not
  write a test that expects one leg per pass. It also means a "both legs drain,
  then inspect the final state" test **cannot** pin an ordering rule: fail one leg
  (`failFirstRpcCalls`) to observe the state in between.
- Legs enqueued in the same millisecond share `createdAt`, so queue order is not
  a reliable "A then B". Assert over whichever leg is not `synced`.
- A retrying leg's status is `pending`, not `failed` — only a leg that exhausts
  `kSyncMaxAttempts` is marked `failed`.

---

## Phase 2 P1.1 — durable leg→invoice attribution (closes P1's settlement residual)

DONE. P1 shipped issue 3 with a documented limitation: leg→invoice attribution
read the leg's RPC params (`p_invoice_id`), which a `settle_supplier` leg does not
carry — the server picks what to allocate, so the client never knows until replay.
A still-queued settlement was therefore protected only by the markers it stamped
itself, and a later money leg on one of its invoices that drained first retired
the marker anyway. P1.1 closes it.

**Reproduced first.** `settlement_money_attribution_test.dart` blocks one RPC **by
name** so a flush drains the payment but leaves the settlement queued. Two cases
failed before any code moved, both with the marker reading `null` where the
settlement's leg id was correct: one invoice, and one of two invoices in a
multi-invoice settlement. The test needed a name-blocked target rather than a
call-count one because the flusher drains a whole dependency graph in one pass.

**Storage — local only.** drift schema **7** adds a nullable
`sync_queue_items.affects_invoice_ids` TEXT column (JSON array of invoice ids),
mirroring the existing `depends_on`. Written once, inside the same transaction as
the local mutations and the enqueue, and never mutated afterwards; the queue
*status* is what makes a leg active. `recordPayment` records `[row.id]`;
`settleSupplier` records the deduplicated `allocations.where((a) => a.dueId == null)`
invoice ids — due allocations are excluded because they only mutate commission
dues, not invoice money figures. **No Supabase migration, no RPC change, and
nothing new in the RPC body or params.**

**Resolution.** `resolveInvoiceMoneyMarker` now re-evaluates the union of (a) the
rows the completing leg stamps and (b) the leg's recorded attribution, and
matches outstanding legs on tenant + attribution with a `p_invoice_id` fallback for
pre-v7 legs. The attribution half is what makes resolution independent of marker
history. Every scan and update is tenant-scoped, and the outstanding legs are
ordered by `(createdAt, id)` — `createdAt` alone is not a total order, so two legs
enqueued in the same millisecond would otherwise resolve by row order.

**No backfill, on purpose.** A pre-v7 `record_payment` leg is recoverable from its
params at read time, so the migration writes nothing. A pre-v7 `settle_supplier`
leg is *not* recoverable — the server chose the allocation and the local mirror may
have changed since, so any value written at upgrade time would be invention rather
than evidence. The residual is now narrow and self-healing: it affects only legs
already queued at upgrade time, they keep today's behaviour, and they disappear
once they drain. Both halves are pinned in `leg_attribution_migration_test.dart`.

**What mutation testing actually established.** Seven mutations were run, and two
results changed the code. Dropping the attribution, dropping the `status != synced`
filter, dropping the tenant filter, dropping the `id` tie-break, removing the
`addColumn`, and adding a `p_invoice_id` backfill were each killed. But **dropping
the stamped half of the union passed the entire suite** — under every reachable
state the two halves agree, because a resolve only ever re-stamps to another
outstanding leg or clears. Rather than keep an unpinned branch or fabricate a test
requiring a hand-built impossible state, the reason it is kept is written into the
resolver's comment. The suite also grew a test that pins the opposite half
(`resolution depends on the queue, not on which leg held the marker`), because
the union as a whole was previously unpinned in both directions.

**Still deliberately open (not regressions).** A parked `failed` money leg holds
its invoices' local figures indefinitely, because a local mutation the server
never accepted must stay authoritative; recovery UX is its own slice. A corrupt
attribution column degrades to the params fallback rather than throwing, so a
payment is still attributed exactly and a settlement is attributed to nothing.

**Files.** drift `sync_queue_items.affectsInvoiceIds` (schema 7, additive `< 7`
migration); `LocalStore.parseInvoiceAttribution` / `parseLegacyTargetInvoice` /
`_legInvoiceIds` / `resolveInvoiceMoneyMarker`; `offline_write.dart` (attribution
persisted in the existing transaction); `offline_sync.dart` (comment only — the
call site did not change). No `presentation/` change.

---

## Phase 2 P2 — issues 1 and 2 (offline invoices look wrong on return)

DONE. Both reported issues were one defect seen from two sides: an invoice saved
offline appeared in the list but rendered as if the server had already accepted
it, and the app-wide pending count never moved. Phase 2 is now complete (P0, P1,
P1.1, P2).

**The defect, stated precisely.** `_newInvoice` in both invoice screens called
`ref.read(<list>Provider.notifier).refresh()` after the form popped. That is the
right trigger for the *list*, and it worked — the row really did appear. But
`pendingSyncCountProvider` and `invoiceSyncStatesProvider` read the **sync queue**,
not the list, and nothing invalidated them. Both are one-shot `FutureProvider`s
with no self-polling, so the pre-write value (`0` and `{}`) survived until a
drain, at which point `_refreshAfterDrain` fixed the display. In between, the app
said "everything is synced" while the user's own invoice sat unsent — precisely
the failure Phase 1A.1's badge exists to prevent.

**Fix — one shared trigger, Dart-only, no schema and no RPC change.**
`refreshAfterLocalInvoiceWrite(WidgetRef ref)` in `offline_sync_providers.dart`
invalidates the pending count, the badge map, and both invoice list providers, and
**both** screens call it, so sales and purchases cannot drift apart again. It is a
refresh trigger only: the list notifiers still own how they load. It takes a
`WidgetRef` because the callers are screens, and a `WidgetRef` is not assignable
to the provider-side `Ref` that `_refreshAfterDrain` takes — so the two helpers
cannot be merged, and that is documented at the definition. The sale form's route
result also changed from a bare `String` to `({String no, bool pending})` so the
SnackBar can branch; it now says `تم حفظ فاتورة البيع محليًا وستتم مزامنتها عند
عودة الاتصال`, matching the purchase wording the user asked to align to.

**The two handoff hypotheses were both wrong, and the tests said so.** P2 assumed
issue 1 was a missing entry in `_refreshAfterDrain`'s set. It was not: the list
provider *was* refreshed correctly and the merge *is* filter-aware, so the row
always appeared. Only the queue-derived pair was stale. Root causes are recorded
separately as A (post-save invalidation re-runs the list), B (the re-run merges the
`synced == false` draft), C (the queue-derived providers recompute at write time)
and D (the list and the form use the right provider; the defect is an incomplete
invalidation set, not a wrong list key) — the tests confirm A and B were already
satisfied and C was the whole defect.

**A false positive caught before it shipped — worth keeping.** The first version of
the sale test probed the row with `find.textContaining('D-')` and it passed
*against the unfixed code*. `InvoiceListView` renders the number in a chip showing
only the **last three characters** (`_shortNo`), so the full `D-…` string was never
on screen — the finder was matching the **SnackBar**, which quotes the number, and
would have passed even if no row were painted at all. The probe is now derived from
durable state (`_shortNo(draft.no)` from the mirror row), so it cannot pass without a
row. Same class of trap as "never assert a constant against itself".

**A second vacuous assertion, caught by mutation testing.** With the purchase
screen reverted to `.notifier.refresh()`, the purchase test still passed. Two
independent reasons: a provider nobody has read is rebuilt on first access and so
reports the correct value regardless, **and** these are auto-dispose providers whose
only listener is `InvoiceListView` — which is not built at all while the list is
empty, so the provider was disposed before the write and re-created fresh after it.
`holdQueueProviders` in the harness now reads both providers *and* holds a
`container.listen` subscription open across the write, which is what makes the
write-time invalidation observable at all. This is the same lesson as
`invoice_sync_badge_test.dart`'s drain case.

**`_refreshAfterDrain` is not a write-time helper, and a drain does not empty the
badge map.** Two things the tests had to be corrected against: the post-drain
assertion is "no leg is left `pending`/`failed`", not "the map is empty" —
`queueLegsFor` returns *every* leg and the drained one maps to `synced`, which is
exactly what makes the row render unbadged. And awaiting a provider's future inside
`runAsync` **deadlocks** when the rebuild was triggered from that same `runAsync`
(a drain invalidates the lists), so the harness settles with bounded real-timer
rounds; the reasoning is documented on `settleInvoiceReads`.

**Test-only facts worth carrying.** A purchase leg posts its credit to account
**2010**; a seed without it fails with `Required account not found in chart of
accounts: 2010` and the form silently stays open on an inline error. The row's party
name and the `Money.format(total)` cell are the reliable row probes; the number
chip is not. `cacheLast` is still **network-first** (the Slice A.5 flip applied to
`cacheFirst` only), so a post-drain list refetch does return the server's row rather
than a stale cache.

**Mutation-proven four ways**, each failing a different assertion: dropping the
count invalidation, dropping the badge invalidation, reverting the purchase screen
to `.notifier.refresh()`, and un-branching the sale SnackBar.

**Files.** `offline_sync_providers.dart` (`refreshAfterLocalInvoiceWrite`),
`sale_invoices_screen.dart` (helper + `({String no, bool pending})` result + pending
message), `purchase_invoices_screen.dart` (helper), new
`test/tool/offline_invoice_harness.dart` and
`test/widget/offline_invoice_list_write_test.dart`. No `data/` change, no migration,
no RPC, no schema change.

---

## Phase 2 P1.C — corrective slice (invoice mirror authority, double-submit, action lifecycle)

Four defects, all in code the P1 slice had just written. None is a new feature and
none changes a server contract.

- **Invoice reads never reached the mirror.** `local_invoices` was written but
  never refreshed, so the P1.1 badge worked while the *list* the user actually reads
  kept showing pre-write figures. `OfflineInvoiceRepository` now ends every
  `list(type:)`/`list(status:)` with `_mirrorHeaders`, feeding a new
  `LocalStore.mirrorInvoices(tenantId, rows)` through `cacheLast(mirror:)`. The mirror
  is **header-only** — `requestId`/`createdAt` are nulled, `synced = true`,
  `pendingMoneyLeg = null` — because `local_invoice_lines` is never mirrored, so a
  header carrying server line figures would describe lines that do not exist locally.
- **`insertOrReplace` on an id-only primary key deletes a foreign tenant's row.**
  `local_invoices` is keyed `{id}` alone, so `ON CONFLICT DO UPDATE` matches on the
  key alone and a same-id row belonging to another tenant is silently replaced.
  Replaced with a **tenant-scoped `delete` + plain `batch(insert)` inside one
  transaction**: a foreign-tenant collision raises and rolls the whole mirror back.
  A tenant switch would otherwise have destroyed the other workspace's invoice.
- **A replayed invoice was mirrored twice.** `markReplaySynced` keeps the *local* id
  (the sync badge joins the queue on the leg's `localId`) and records local→server in
  `id_map`. The next online read then sees the server's id as a different primary key
  and inserts a second row. `mirrorInvoices` now resolves each incoming id through
  `localIdFor` and **updates the mapped row in place** rather than inserting.
- **A sheet could submit twice, and a valid submit threw an opaque error.** The four
  submit paths now hold an imperative `if (_submitting) return;` guard (the disabled
  button is not a guard — two taps can both land before the rebuild), and the four
  `PaymentActions`/`SalaryActions` providers are `@Riverpod(keepAlive: true)`: a sheet
  only `ref.read`s them, and Riverpod 3 auto-disposes an unused action provider at the
  `await`, so the *next* call hit `UnmountedRefException`. **The sheets were opening
  and closing purely because of test-harness listeners**; the real fix is
  `keepAlive`, and the three harnesses are now one-shot.
- **Bonus, same root cause as P2:** the four money actions invalidate
  `pendingSyncCountProvider` themselves, gated on `result.pending == true`, so the
  header count cannot lag the write that just happened.

**Evidence:** 769 → **785**, all green. Regression groups P2 `6/6`, money guards
`43/43`, related `169/169`; full suite `785/785`; `flutter analyze` clean; web and
debug APK builds green.

**Mutation evidence:** `id_map` lookup stubbed to `null` (→ A1-I and the reconnect
drain both fail on duplicate rows); `keepAlive` removed from `SalaryActions` (→ the
salary race test fails via `SheetErrorBanner`) and from `PaymentActions` (→ all three
payment/settlement cases fail); pending-count invalidation made unconditional (→ the
negative pending case, expected 1 / actual 5).

**Still open — not a regression.** Issue 4's original device failure remains
undiagnosed. An employee-movement phase trace (repository → coordinator → action
→ sheet, phases + raw errors, no business data) was added across those layers,
but a local run produced no error at all and **it was removed again at the P1.G
cleanup without ever having captured a diagnosis** — a debug-only trace that
prints nothing in release cannot be collected from the shipped APK, and no
reproduce was obtained. **A behavioural fix must not be attempted from a
symptom that was never captured**; treat the original report as open until a
physical reproduction with an instrumented build is in hand.

---

## Phase 2 P1.D — corrective slice (cached invoices were visible but unwritable; a paid month read as payable)

819 tests, all green, analyze clean, web + debug APK green. Two defects, both
reached in the field rather than by a failing test.

### Defect 1 — an invoice restored from the durable cache was never in the mirror

**The state.** A device that read an invoice list before the mirror existed holds
the list in `report_cache` and nothing in `local_invoices`. `cacheLast` served that
cache happily, so the invoice painted on screen and the mirror stayed empty — the
same "visible but not locally writable" shape P1.C fixed for the online path, one
step earlier in the read lifecycle. The user then opened the invoice and the money
write failed with `الفاتورة غير موجودة محلياً` against an invoice they could see.

`cacheLast` has **no success/failure signal** — it returns the payload or throws,
and nothing about which path produced it. So it cannot be the thing that
hydrates, and the generic helper was left alone. `OfflineInvoiceRepository` now
ends the cached path with `_mirrorHeaders(merged)`, on the **final merged list**
rather than the network payload, so a locally-overridden header is hydrated under
the shape the user is actually shown. The invoice-specific `mirror:` callback was
removed, because a callback only runs on the network branch and this defect is
on the cache branch.

**The other half of the defect was a mapped id, and it is the one with the wider
blast radius.** `markReplaySynced` keeps the **local** uuid (the sync badge joins
on the queue leg's `localId`, so re-keying would break it) and records
local→server in `id_map`. A replayed invoice is therefore stored under one id and
served under another, and `OfflineWriteCoordinator._invoice` resolved **only** by
exact local id. Every money write against a replayed invoice was refused. The
resolver now falls back to the tenant/entity-scoped `localIdFor(..., 'invoices',
...)` lookup. `settleSupplier` needed nothing: it scans purchase rows by
`partyId`/`remaining` and never resolves an invoice by id, which is why this
survived the earlier slices.

**Two decisions worth keeping.**

- **The cross-tenant same-id collision is resolved by skipping the row, not by
  letting the insert raise.** P1.C made a foreign collision raise and roll the
  whole mirror back. That is right for *authority* — it stops a second workspace's
  invoice from being overwritten — but it is wrong here: one colliding uuid in a
  page of twenty would leave the other nineteen unhydrated, i.e. the original
  defect one level down. Colliding ids are now partitioned out before the insert
  and their safe siblings are written. The skipped invoice is the **one documented
  exception** to "anything `list()` returns is locally resolvable": the schema is
  keyed `{id}` alone and the read cannot invent the other workspace's row. A
  payment against it fails honestly.
- **Hydration errors are not swallowed.** No `try/catch Object` around
  `_mirrorHeaders`. The rest of the mirror layer is best-effort, and it is
  tempting to match it here, but a genuine drift failure would then be reported as
  a successful read whose invoices silently do not resolve — the same lie as the
  bug. The `NetworkException` branch needs no hydration call at all: those rows
  came out of the mirror in the first place.

### Defect 2 — a paid month read as payable

`netDue` is the month's entitlement and **must not** shrink when it is paid —
zeroing it would look like a fix and would also corrupt the arrears base. The
defect was that the read model had nowhere to put the fact of payment:
`EmployeeEntitlement` had no paid flag, `salaries_screen.dart` labelled the gross
`صافي المستحقات` directly above the pay button and gated the button on it, and
the pay sheet both defaulted and capped its amount on it. The net effect was a
paid month presented as fully payable, with no status at all, behind a
disabled-looking button that was in fact enabled.

- `EmployeeEntitlement` gains a **required** `isPaidForMonth` and a derived
  `currentPayable => isPaidForMonth ? 0 : netDue`. Required, not defaulted: a
  default would let a new construction site silently read as unpaid, and "I
  forgot to pass the paid state" is exactly the bug being fixed. `fromJson` passes
  `false` because the entitlement RPC has no such field.
- `OfflineSalaryRepository.entitlement` composes `serverPaid || localPaid`. Both
  halves are needed and they cover disjoint windows: before the drain only the
  local row knows, after it only the server does on a device whose mirror was
  cleared or never written. The offline branch reads the paid state from **the
  same rows** the figures were computed from, so "paid, 0 payable" can never be
  rendered beside figures from a different snapshot.
- `SupabaseSalaryRepository.entitlement` keeps the RPC for the gross and adds a
  narrow `salaries` existence query for the paid flag. No new RPC, no migration.
- The month formats are now explicit rather than implicit: local
  `local_salaries.month` is `yyyy-MM`, the server's `salaries.month` is
  `yyyy-MM-01`, and `salaryMonthKey` / `salaryMonthDate` are the only two places
  either is produced. `offline_write._monthKey` was building its own third copy.
- `SalaryActions.pay` re-reads the live entitlement before writing. The
  coordinator's duplicate-month guard is **device-local** — it inspects
  `local_salaries`, this device's own mirror — so on a cleared or offline device
  it has nothing to find and would queue a second payout for a month the server
  already holds. The re-read answers with the same Arabic message the write guard
  uses, instead of a server validation error.

### A test that encoded an unreachable state, and a fixture that was too short

- The original tenant-isolation case asked tenant A's repository for an
  entitlement on an employee that only exists in tenant B, and asserted the answer
  was "unpaid". It failed, and correctly: the read **throws**
  (`الموظف غير موجود محلياً`), because `LocalEmployees` is keyed `{id}` alone so
  the same id cannot exist in two tenants and no user can reach that state. It
  was replaced by the two cases that can be reached — a shared month where one
  workspace is paid and the other is not (matching on the month alone, or scanning
  without the tenant filter, fails this) and the fail-closed throw.
- The post-pay widget case asserted `find.text('5000')`, which matches **twice**
  before a payout (gross and payable are equal when unpaid) and would still match
  the gross alone after the relabel. It passed against a half-fix. The probes are
  now derived from rendered label+value pairs, and the post-pay case asserts the
  gross *survives* the payment as well as the payable going to zero — the tempting
  wrong fix would satisfy the payable assertion on its own.
- The dynamic `isPaidForMonth` / `currentPayable` probes these RED files carried
  are gone. `(ent as dynamic).x` swallows a missing member into "unpaid", which is
  indistinguishable from the bug being pinned, and a dynamic read asserts nothing
  about a real member's type. A direct reference that stops compiling is the
  stronger signal.

### Verification

`flutter analyze --no-pub` clean. `flutter test --no-pub` **819/819**.
`flutter build web --dart-define=use_arabic=true` green (167.7s).
`flutter build apk --debug` green (131.6s). Encoding checked at byte level on all
14 touched files: 0 U+FFFD, 0 mangled Arabic literals.

**Mutation-proven seven ways, each failing a different assertion so none is
covered by the others:**

| Mutation | Fails |
|---|---|
| `await _mirrorHeaders(merged)` removed | 10 invoice cases (B1–B4, C1–C3, D4×3, E1) |
| `_invoice`'s `localIdFor` fallback → `null` | C1b |
| unsynced-draft + pending-money protection in `mirrorInvoices` dropped | D1 **and** D2 |
| the foreign-id partition emptied | D4a, D4b, D4c |
| local paid state forced to `false` | S2a, S2c, S4a, S5a, S7a |
| the server half of the `||` dropped | S3a only |
| `canPay` reverted to `netDue > 0` | the post-pay widget case only |

The stale-sheet guard was proven the same way, and it needed a **new** test to
have teeth: the existing race and inline-error suites stayed green with the guard
removed, because both drive a repository whose `entitlement` never changes. The
fake now carries a mutable paid flag so the state can move *while the sheet is
open*, which is the only way the case is expressible.

### Still open — not regressions

- **Device verification.** Everything above is automated evidence. The salary
  card's relabel, the paid indicator, and the Arabic wrapping of all three new
  strings render with the test font here, not Cairo — the on-device visual check
  is still the user's step.
- **Issue 4 remains undiagnosed** and untouched by this slice: the
  employee-movement trace added in P1.C is debug-only and silent in release, so
  it can only be collected from an instrumented debug build on the physical
  device before any behavioural fix — and it was removed unused at the P1.G
  cleanup. Do not attempt a fix from a symptom that was never captured.
- **The discard-at-the-boundary gap** is unchanged for payments, products,
  customers, suppliers, employees, journal entries and salaries; `queueLegsFor`
  takes an `entity` filter so each is one provider away.
  `supabase/tests/0025_idempotency.ps1` remains applied-but-unconfirmed.

---

## Handoff to the next phase

- **What P2 leaves in place.** The queue-derived read path is now invalidated on
  **both** edges — write (`refreshAfterLocalInvoiceWrite`) and drain
  (`_refreshAfterDrain`). Any new provider that reads the queue or the invoice
  mirror must be added to **both** sets, or it will be stale for exactly one of them.
  The badge map is keyed by *local* invoice id and deliberately keeps drained legs
  (as `synced`); "no badge" comes from the row id no longer matching, not from an
  emptied map.
- **Still open, not regressions.** The same discard-at-the-boundary gap remains for
  payments, products, customers, suppliers, employees, journal entries and salaries
  — `queueLegsFor` takes an `entity` filter precisely so each is one provider away.
  A parked `failed` money leg keeps its invoices' local figures authoritative
  indefinitely (recovery UX is its own slice). `supabase/tests/0025_idempotency.ps1`
  remains applied-but-unconfirmed.
- **Badge has automated evidence only.** The measurements and state transitions are
  mutation-proven, but tests render with the test font, not Cairo — the visual check
  on a device is still outstanding.
- **P1.C does not reopen the "both edges" rule.** `pendingSyncCountProvider` gained a
  third invalidation site (the four money actions, gated on `result.pending`). Any new
  queue-reading provider still has to be added to the write edge *and* the drain edge;
  a per-action call is not a substitute.
- **Issue 4 is still blocked on the device, and the trace is deliberately silent in
  release.** Do not "fix" movement parsing from a reproduction you did not capture.
- **P1.D adds the two rules this slice had to re-derive.** (1) Anything
  `list()` returns is locally resolvable — with exactly one exception, a
  cross-tenant same-id collision, which is skipped and documented; the mirror is
  hydrated from the **final merged list**, not the network payload, and hydration
  errors are deliberately **not** swallowed. (2) A money write against a
  **replayed** entity must resolve through `id_map`, because `markReplaySynced`
  keeps the local id by design (the sync badge joins on it) and the entity is
  served under a different one. `settleSupplier` is the exception that proves the
  rule: it resolves invoices by `partyId`, never by id.
- **"Visible on screen" is not "resolvable on disk."** Both of P1.D's defects had
  that shape, and both escaped a green suite because a `find.text` on an amount
  matched more than one row. Derive a widget probe from a rendered label+value
  pair, and prefer a count of *entries into the write path* over a count of
  rejected writes.
- **A device-local duplicate guard is not a duplicate guard.** The salary month
  check reads `local_salaries`, this device's own mirror, so it cannot see a
  payment made on another device. Anything that must be globally unique per
  period needs a server- or live-read-backed check on the write path, not a local
  row.

---

## Phase 2 P1.E — corrective slice (invoice line items were not durable, ordered, or tenant-safe)

P1.C made the invoice **header** mirror authoritative and P1.D made every listed
invoice locally resolvable. The **lines** had been left behind by both: they were
written by the offline writers but never mirrored from the server, keyed by `id`
alone, and given no ordering. 819 → **849**, analyze clean. **No Supabase-side
change** — no migration, no RPC, no new column in Postgres.

- **The line table had the same `{id}`-only trap the header had, one level down.**
  `local_invoice_items` was keyed `{id}` alone while every writer used
  `insertOrReplace`, so mirroring one workspace's lines for an invoice id another
  workspace also held silently **replaced** the other workspace's row. Drift
  schema **8** moves `tenant_id` into the primary key (`{tenantId, id}`) and
  rebuilds the table. **`local_invoices` and `local_suppliers` still carry the
  `{id}`-only key** and are unchanged by this step — the fix is per-table, and
  there is no schema-wide invariant to lean on.
- **A primary key change is a rebuild, and a rebuild has exactly two claims to
  prove.** `deleteTable` + `createTable` + `insertAll` is the same shape as the
  schema-5 `id_mappings` rebuild, and `invoice_items_key_migration_test.dart`
  pins both claims by mutation: dropping the re-insert fails the row-survival
  case, and making the rebuild a no-op fails with
  `UNIQUE constraint failed: local_invoice_items.id` — i.e. the defect itself,
  reproduced rather than described.
- **No backfill, and that is a different decision from schema 5's sentinel.**
  `tenant_id` was already `NOT NULL` and every writer has always set it, so a
  pre-v8 row already states its own owner and moves across unchanged.
  Re-attributing would be invention; dropping would be silent data loss on a
  user's offline invoice. Consequently "the tenant survived" is the *same*
  assertion as "the row survived" — it is asserted once, not twice, because a
  second case would look independent while testing nothing new.
- **Legacy bare-uuid line ids stay readable and are never rewritten.** The
  pre-v8 writer minted a uuid per line; the ordinal of a uuid row was never
  recorded, so minting a positional id during migration would be fiction. Reads
  therefore order by `id`, which is correct for both schemes. **Original
  invoice order is unrecoverable for pre-v8 rows and is documented, not faked.**
- **New line ids are positional, zero-padded to 4 digits.** `LocalStore.invoiceLineId(invoiceId, index)`
  → `'$invoiceId:${index.toString().padLeft(4, '0')}'`, used by both the pending
  Sale and Purchase writers. Padding is load-bearing, not cosmetic: without it a
  plain lexicographic `ORDER BY id` sorts `:10` before `:2`, which is invisible at
  9 lines and wrong at 10. **Do not "simplify" this to `':$index'`.**
- **`mirrorInvoiceItems` is replace-all inside one transaction**, which is what
  makes an empty refresh (`[]`) able to clear a synced invoice's lines. Two
  guards ride on it: it **refuses to sweep an unsynced header** (a background
  refresh must never destroy pending local work, the same rule as
  `_mirrorPreservingUnsynced`), and it is **tenant-scoped on both the delete and
  the read**.
- **`items()` resolves the server id before anything else.** A replayed invoice
  is stored under its local uuid and served under the server's, so the read path
  maps through `localIdFor(tenant, 'invoices', invoiceId) ?? invoiceId` first —
  P1.D's rule applied to lines.
- **A cached `[]` is a legitimate answer and wipes the mirror.** An unsynced
  draft bypasses `cacheLast` entirely; a synced invoice follows the final
  network/cache value, and if that value is `[]` the mirror is emptied. The first
  version of the durability test overwrote the cache with a conflicting `[]` and
  pinned the wrong thing; it now **deletes the cache row** so the local mirror is
  the only source.
- **The migration has no "does this table exist?" guard, and that is the same
  rule P1.1 recorded for its fixtures.** `local_invoice_items` has existed since
  schema 1, so a file without it is corrupt. A guard would convert that corruption
  into a **successful** upgrade with an empty table — the user finds their
  invoice lines gone and nothing is logged. Failing routes the device to the
  repair screen. Two existing migration fixtures omitted the table and failed as
  `no such table`; **the fixtures were corrected, not the migration.** An
  under-specified fixture gets fixed, it does not get a migration that hides it.
- **Migration fixtures must pin the shape they upgrade FROM.** A fixture that
  quietly drifts toward the current definition proves nothing, because the upgrade
  would have nothing to do. Each case reads the file's own DDL back out of
  `sqlite_master` while the fixture's connection is still open.
- **Device check PASSED (2026-10-02)** for the historical-hydration path: an
  invoice listed offline rendered its durable product lines. Two honest residuals
  remain: the rendered line **order** still has no human visual audit, and no real
  `create_sale_invoice`/`create_purchase_invoice` replay carrying `p_items` back
  into the line mirror has been exercised on hardware.

---

## Phase 2 P1.F — list-time line hydration, mapped-row money authority, search, validation order

Five defects found against P1.E's output, all of them "the fix landed but the
neighbouring invariant did not". 849 → **880**, analyze clean, web + debug APK
green. **No Supabase-side change** — no migration, no RPC, no schema change, and
drift stays at schema 8.

- **P1.E made the lines durable only for the invoice the user OPENED.**
  `mirrorInvoiceItems` is written by `items(id)`, so a device that listed twenty
  invoices and opened none had headers and no lines — which is exactly the state
  the user sees, since a list is not a detail. `OfflineInvoiceRepository.list`
  now ends with `_prefetchDetails(merged)`, after `_mirrorHeaders` (the header
  write is what turns a server-listed id into a local row the lines key
  against, and `mirrorInvoiceItems` refuses to sweep an unsynced header).

- **The obvious fix is the forbidden one.** A loop of `items(id)` is N+1, fails
  halfway, and — because `items(id)` cache-lasts per invoice — would re-ask for
  every invoice on EVERY refresh, including every refresh while offline. So the
  candidates are narrowed by **one** bulk local query,
  `LocalStore.invoiceIdsWithDurableItems` (a single `selectOnly` + `groupBy`
  scan, tenant-scoped), and only genuinely missing ids are asked for. Chunking
  the 100-id transport bound lives **inside** `InvoiceRepository`, never in the
  caller: the caller passes the whole missing set once.

- **`InvoiceItemsBatch` exists because "answered with nothing" and "not answered"
  are different facts.** `Map<String, List<InvoiceItem>> items` /
  `Set<String> failed`: a present key holding `[]` is a successful empty answer
  (authoritative — it may clear a synced invoice's lines), while a `failed` id
  is unavailable and its durable rows must be left **exactly** as they were.
  Collapsing the two would make every failed read erase its lines.
  `itemsForInvoices` seeds every successful id (including `[]`), orders by
  `invoice_items.id` for deterministic order, and never throws per chunk.

- **The prefetch had to resolve the id space on BOTH sides, and the read side was
  the one that was missed.** A replayed invoice is stored under its local uuid
  and listed under the server id (P1.C), so the candidates `merged` carries are
  SERVER ids while `local_invoice_items.invoiceId` is keyed by the LOCAL one.
  Comparing them directly matches nothing — which is byte-for-byte identical to
  "these lines were never fetched", so a replayed invoice was re-requested on
  every list refresh, forever, and re-mirrored into a **second** set of lines
  beside the local one. `invoiceIdsWithDurableItems` now resolves the mapping
  itself (one `isIn` read of `id_mappings`, then one grouped scan) and answers in
  the caller's id space; the repository still re-keys each successful answer
  through `localIdFor` before `_mirrorItems`. Both halves are separately pinned,
  because fixing only one leaves the refetch or the duplicate in place.
  **The resolution belongs inside the store, not the call site:** a per-id
  `localIdFor` at the call site would be one extra query per invoice — the N+1
  this design exists to avoid, relocated rather than removed.

- **A `NetworkException` from the prefetch is swallowed, `Object` is not.** The
  header list must never depend on optional hydration, so an unreachable server
  cannot take the invoice list down with it. The durable lookup and the mirror
  stay outside the `try` for P1.D's reason: a genuine drift failure there must
  surface rather than be reported as a successful read whose invoices silently do
  not resolve.

- **A mapped row's local money and marker were both being overwritten.**
  `mirrorInvoices` built its protection set from **local** ids and filtered
  **server** ids, so for a row this device minted the two never compared equal:
  the mapped row fell through to the update branch and the server's pre-payment
  money was written over the local correction, clearing `pendingMoneyLeg` in the
  same statement. Every incoming id is now resolved to its effective local id
  **up front**, and both the filter and the update consume that same value.
  Cost is unchanged — one indexed `id_map` read per row, hoisted above the filter
  instead of below it.

- **The product picker's search box was inert.** `product_picker_sheet.dart` is
  the only writer of `productSearchProvider` and it watched `allProductsProvider`,
  which never reads that provider — so the sheet rendered the same catalog
  whatever the user typed, online and offline. Now watches `productsListProvider`
  (`products_screen.dart` already did). Reopen works because the generated
  provider is `autoDispose`. Sale/Purchase duplicate selection is unchanged and
  pinned as characterization; **no `excludeIds`** was introduced in either
  direction.

- **`writeSale`'s honest Arabic refusal was unreachable.** The unknown-product
  check ran *after* the `engineLines` comprehension that dereferences
  `products[l.productId]!` for the default price, so the `!` threw first and the
  `ValidationException` was dead code for exactly the case it was written for
  (`_guard` maps `StateError`/`ArgumentError`, not `TypeError`). Validation now
  runs first, over `draft.lines` — the input domain, before priced lines exist.
  Deliberately narrow: **no broadened `TypeError` mapping.** `writePurchase` was
  already safe and got a comment marking it as the reference shape.

- **Two test defects, both of the "green suite over broken code" kind.**
  `sheet_inline_error_test.dart` stubbed `allProductsProvider`, which the picker
  stopped reading, so the case failed looking for a product row that never
  rendered — the error named the tap, not the missing stub; it now stubs
  `productRepositoryProvider`. And `A3`'s original assertion (`singleInvoiceCalls`
  empty) would pass for an implementation that loops
  `itemsForInvoices([id])` — three batch calls, none over 100 — so the **exact id
  set of each call** is asserted instead.

- **Mutation results worth keeping.** M1 (raw server id in `mirrorInvoices`) was
  killed by **C7**, not by C3/C5 — the over-protection guard is what notices the
  id-space slip, which is the opposite of the prediction and a good argument for
  having written it. M2 (`allProductsProvider` restored) killed B1 **and** B1.3.
  M3 (hydration disabled) killed A1/A2/A3. M4 (N single reads instead of one
  batch) killed A1/A2/A3. M5 (Sale validation moved back after the dereference)
  killed B4.3 with a raw `TypeError`. M6 (resolve the mapping to itself in the
  durable check) killed **A7 alone**, leaving A7b green — the two cases fail for
  different reasons and neither covers the other. Each mutation was reverted
  before the final run.

- **A7/A7b pin the cost side of the design, which no earlier case covered.** A7
  seeds the real replayed shape (synced header under a local uuid, lines
  mirrored under that same local id, a `local → server` mapping) and asserts the
  batch is asked for the two invoices that genuinely have nothing durable — not
  the three the page listed. A7b lists twice and asserts the second refresh
  issues **zero** detail requests, offline. Together they are what make
  "already durable" mean something rather than merely "not broken": before them,
  an implementation that re-fetched every invoice forever still passed the whole
  suite. The seeded header is `synced: true` deliberately, because
  `mirrorInvoiceItems` refuses to sweep an unsynced header — an unsynced draft
  could not hold durable lines at all, so the case would pass vacuously.
- **Zero-line invoices are re-asked, deliberately.** A synced invoice with no
  lines has no `local_invoice_items` row, so nothing marks it answered and a
  later list re-requests it. Adding completeness metadata would need a schema
  change for a one-request cost; the retry is accepted and documented instead.

### P1.F.1 — the open invoice's money was stale the instant after a payment

One field-reported defect, and the **only** code change is
`InvoiceDetailSheet`. No data-layer change: the mirror, the `pendingMoneyLeg`
authority and `PaymentActions._refresh()` were all already correct and are proven
correct here.

- **The root cause is a snapshot, not a missing refresh.** Both invoice screens
  open the sheet as `builder: (_) => InvoiceDetailSheet(invoice: invoice)` — the
  row as the list held it at tap time. `InvoiceDetailSheet` was a
  `ConsumerWidget` that **watched nothing**, and a modal route is not rebuilt when
  the widget that opened it rebuilds. So `_refresh()`'s invalidation did rebuild
  the list *behind* the sheet (the device proved that: the row is correct after
  you dismiss it) and the sheet above it kept rendering the frozen `paid` /
  `remaining` / `status` — while the SnackBar the write raised quoted the
  correct new remaining. Its only `FutureBuilder` was `ref.read`-ing
  `items(invoiceId)`, which refreshes **lines**, never the header.
- **The fix is a second subscriber, not a second read.** `_liveInvoice` watches
  the *existing* `saleInvoicesListProvider` / `purchaseInvoicesListProvider`
  (chosen from `type`) and resolves the row with the same identity the list
  exposes. The invalidation already rebuilds that exact provider for the list
  behind the sheet, so this adds no I/O of its own, and it keeps `_merged` the
  single authority for local pending money instead of re-deriving that rule in
  the UI. All header/money reads moved to the resolved row — `paid`, `remaining`,
  `status`, `no`, `partyName`, `date`, `total`, the `remaining > 0` button gate,
  **and the invoice handed to the payment sheet**, so its amount validator and
  default are the live ones too.
- **A dedicated single-invoice provider was rejected deliberately.** It would
  react regardless of list filters and be instant, but it needs either a new
  repository method or a second copy of the `synced` / `pendingMoneyLeg` authority
  rule — a second source of truth that can drift from `_merged`.
- **`_RecordPaymentSheet` was left alone**, per scope: its submit path already
  re-reads live remaining before mutating, so its snapshot is not this defect.
- **The fallback is snapshot-based and deliberately so.** Loading, error and
  "not in the current filter" all fall back to the captured row, so nothing
  flickers to a spinner. A row the active search or date filter excludes would
  therefore read stale — accepted for this slice, because the sheet was opened
  from that same filtered list and a payment changes neither the invoice's type,
  number, party nor date, so it cannot leave the filter on its own.
- **The regression proves the SAME mounted sheet updates** — no close/reopen, no
  manual `ref.invalidate`, no provider-container recreation, no
  `Future.delayed`, no fake post-payment invoice. Sale and purchase are both
  pinned (one shared component, two providers). Both transitions are pinned:
  `100000/0` → pay 400 → `جزئية` + `40000/60000` → pay 600 → `مدفوعة` +
  `100000/0` and `تسجيل دفعة` gone. `listCalls` growing after each write is
  asserted too, so a pass cannot come from a first read instead of the
  invalidation. The durable mirror row is asserted at every step, so a data-layer
  cause cannot be mistaken for a UI one.
- **Probes are label+value pairs, never a bare amount.** Once the invoice is paid
  off, `المدفوع` and `الإجمالي` render the same amount — the same trap as the
  income-statement salary probe.
- **A real ordering constraint fell out of it:** `_canPay` does
  `ref.read(authStateProvider)` at build time, so a sheet built **before** the
  auth stream delivers renders with no payment button and never rebuilds. The app
  cannot hit this (it gates its first frame on `localStoreProvider` and the shell
  watches auth long before a row is reachable), but a test that drives providers
  directly must settle the auth graph **before** the list resolves and the sheet
  opens. Also: cast `element.widget`, never the element — `Text` extends
  `StatelessWidget`, so its element is a `StatelessElement`.
- **A SnackBar sits exactly where the detail sheet's own payment button is**, so
  a second tap is swallowed by it and the failure then reads as "the button is
  gone" instead of "the figure did not change". `pumpAndSettle` does not advance
  its 4s dismissal timer; the clock must be moved explicitly.
- **Mutation-proven:** reverting **only** the resolution (`final live = invoice;`)
  fails both cases at the first post-payment money assertion with
  `Expected: '400'` / `Actual: '0'` — the device symptom reproduced, not merely
  described. Restored, both green. RED was captured before the fix with the same
  assertion.
- **Verification:** analyze clean (44.9s); focused payment/durability/pending-money
  suites 41/41; invoice-detail, list-write, badge, forms and the layout/overflow
  sweeps 198/198; `flutter test --no-pub` **882/882** (880 + 2);
  `flutter build web --release --dart-define=use_arabic=true` green (268.7s);
  `flutter build apk --debug` green (95.1s); byte-level UTF-8 scan clean on both
  touched files (0 U+FFFD, and the only `?` hit is a legitimate `!= null ?`
  ternary in pre-existing code). Drift stays schema 8; **no Supabase-side change,
  no migration, no RPC.**

### P1.G — a replayed invoice's lines were erased by its own detail read

Two independent defects, both reachable **only** after an invoice is created
offline and replayed, both reported as "the invoice lines disappeared".
882 → **891/891**; analyze clean, web release + Arabic + debug APK green.

- **P1.F.1's reactive header is what exposed this.** `_liveInvoice` made the
  header follow the merged list, and the merged list exposes a replayed invoice
  under its **server** id `S` while its durable lines live under the **local** id
  `L` it was minted with (`markReplaySynced` keeps the local id and records
  `id_map(L→S)`). The detail sheet still asked for `items(invoice.id)`, so the
  one field P1.F.1 had *not* converted — the line read — kept using a captured
  id that the server never issued. Making the header live therefore did not fix
  the lines; it only made the mismatch visible.
- **The id-space rule is the same one P1.E stated for lines, and it was applied
  on the read side too.** `OfflineInvoiceRepository.items()` now resolves
  `localId` (already done) **and** the inverse `remoteId = serverIdFor(...) ?? id`,
  sends `remoteId` to the network and keys the report cache under `invItems:$remoteId`.
  A detail read through **either** id space now reaches the server. Normalizing
  here rather than in the sheet also keeps `id_map` knowledge out of the
  presentation layer — the same reason `_merged` stays the money authority.
- **`items(live.id)` was the requested fix and is a provable no-op.** `_liveInvoice`
  returns a row only when `row.id == captured.id`, and otherwise returns
  `captured` — so `live.id == invoice.id` by construction. The call was reverted
  and only an explanatory comment kept; **M1 therefore SURVIVED** (all 9 focused
  tests still passed with the revert applied). This is recorded rather than
  hidden: the widget-side mutation cannot isolate anything while
  `_liveInvoice` resolves by exact equality, and changing that resolution would
  mean putting `id_map` in the UI.
- **The second defect is a destructive *successful* read.** `cacheLast` returns
  the server's value when it succeeds, and `items()` then mirrored it with
  `mirrorInvoiceItems`, which is replace-all in one transaction. A server answer
  of `[]` therefore **deleted every durable line** — a green, non-erroring read
  destroying data.
- **`[]` is non-authoritative for invoice lines because creation forbids zero
  lines.** `create_sale_invoice` (`0007`:136-138) and `create_purchase_invoice`
  (`0008`:68-69) both raise on an empty `p_items`. An invoice that exists on the
  server cannot have no lines, so an empty detail answer can only be a read-side
  artifact — never evidence that the lines were deleted. **Never mirror `[]` over
  known durable invoice lines.** `items()` now short-circuits: on empty it
  returns `_localItems(t, localId)` and skips the mirror entirely. P1.E's
  "a cached `[]` is a legitimate answer" rule is therefore **narrowed, not
  reversed** — the answer still stands for a genuinely empty invoice, it just may
  no longer *delete* to reach that conclusion.
- **Non-empty remote detail is still fully authoritative and is the repair
  path.** Because `_mirrorItems` replaces the whole set, a correct non-empty
  answer overwrites whatever the local mirror holds — which is exactly how a
  device whose lines were already erased gets them back without Clear Data.
- **R7 is the recovery proof, and it is the reason this slice matters.** It seeds
  the real replayed shape, erases the durable lines under `L` with a direct
  `mirrorInvoiceItems(L, [])` (reproducing the damage the defect caused), then
  reads the invoice **through the normal id space `S`** and asserts the lines
  come back — first in-process, then again after closing and reopening the same
  **file-backed** database. It proves no-Clear-Data recovery for already-damaged
  local detail, with no schema change and no server repair.
- **Device recovery PASSED (2026-10-02).** The user ran it on the physical device
  over the **existing** app data, deliberately **without** Clear Data, and the
  already-erased invoice's lines came back on an online re-read; the same
  invoice then kept its lines through a force-close and an offline re-read.
  R7 predicted exactly this and the device agreed, which is the point of
  building the recovery proof as a reproducing test rather than as a repair
  tool: the repair path already existed in the ordinary read.
- **The transient duplicate invoice was NOT reproduced** on the device or in any
  deterministic test, so no speculative `_merged` fix was made. It is recorded
  as an open observation, not as a closed defect.

---

## Device verification — Phase 2 checkpoint (2026-10-01 and 2026-10-02)

Everything below was run by the user on the **physical Android device**, not
simulated. It is recorded separately from the automated counts because the two
answer different questions: the suite proves the *contract*, the device proves
the *wiring*.

| Checked on device | Result | Slice |
|---|---|---|
| Historical invoice detail hydrates its durable lines offline | **PASS** | P1.E |
| Product-picker search, online and offline | **PASS** | P1.F |
| Payment durability across refresh and restart | **PASS** | P1.F |
| Reconnect → drain → restart, no duplicate | **PASS** | P1.F |
| Money shown immediately after a payment, on the already-open sheet | **PASS** | P1.F.1 |
| Damaged invoice recovers with **no Clear Data**, then survives force-close/offline | **PASS** | P1.G |
| Salary quick smoke (record movement, pay) | **PASS** (functional) | P1.D / Phase 1B |
| Employee-movement quick smoke | **PASS** (functional) | P1.C / Phase 1B |

**Honest limits of that table**, so the next slice does not read it as more
than it is:

- The salary and employee-movement rows are **functional smokes**. They prove the
  write path runs on hardware; they are **not** a Cairo-font visual audit of the
  relabelled salary card or the Arabic wrapping, which still has no human look.
- **Issue 4 remains undiagnosed.** The movement quick smoke did not reproduce it.
  The temporary phase trace added for it never captured anything and has been
  removed — see the P1.C bullet in `AGENTS.md`. Do not attempt a behavioural fix
  from an unreproduced symptom.
- **Unknown-product Arabic validation** is automated evidence only in this
  checkpoint.
- Rendered **line order** on a detail sheet still has no human visual audit.

---

## Appendix A — Implementation Log

| Slice | Commit | DB objects | Tests | Deviations |
|---|---|---|---|---|
| Phase 0 — offline cold start | *(this checkpoint 1/3)* | drift `local_user_profiles` (schema 3) | 432 → 462 | `authRepositoryProvider` became a `FutureProvider`; call sites must `await .future` |
| Phase 1A — queued sales writes | *(this checkpoint 2/3)* | drift `depends_on` (4), `id_mappings.tenant_id` (5), migration `0025` | 462 → 499 → 513 | `0025` adds a parameter with a default, so it **must** `drop function` the old signature first or PostgREST fails with "not unique" |
| Phase 1A.1 — invoice sync badge | *(this checkpoint 3/3)* | none | 513 → 541 | Badge is text-only and absent when synced; `syncing` deliberately not rendered |
| Phase 1B — payments write path | *(this checkpoint 4/4)* | none (driver `depends_on` reuse) | 541 → 555 | Payment sync badge out of scope; no new migration — `0009` already makes both payment RPCs idempotent |
| Phase 1B — purchases write path | *(this checkpoint 5/5)* | none | 555 → 567 | Inline new products use `product_id` (client uuid), never `new_product`; `_enqueueWrite` gained `String? id` (fixes a phantom-`depends_on`); purchase sync badge out of scope; no new migration — `0008`/`0017`/`0018` already cover it |
| Phase 1B — journal write path | *(this checkpoint 6/6)* | none | 567 → 585 | `createJournal` was dead code — rewired to validate against the local chart (missing account → Arabic `ValidationException`), one transaction with `dependsOn` on the account legs; journal list merges **manual-only** unsynced drafts |
| Phase 1B — salaries write path | *(this checkpoint 7/7)* | none | 585 → 611 | `paySalary`/`addMovement` rewritten local-first (Arabic account + missing-employee rejects, local dup-month guard, one transaction, `dependsOn` on pending employee/product legs, rollback-proven); salary sync badge out of scope; no new migration — `0010` salary RPCs already idempotent; server salary rows deliberately NOT mirrored, so the dup-month guard only knows this device's own rows |
| Phase 1B — customers master CRUD | *(this checkpoint 8/8)* | drift: none (schema unchanged) | 611 → 634 | First **hard-delete** offline domain: `pendingDeleteIds` (+`removeMirrorRows`) on `LocalStore`, delete-shape table_crud leg `{'id': id}`, FAILED delete relaxes the read filter; `OfflineCustomerRepository` gained an optional `coordinator:`; SnackBars branch on `customerWritesLocalFirstProvider`; no new migration — `0017` already stamps the customers mirror insert |
| Phase 1B — suppliers master CRUD | *(this checkpoint 9/9)* | drift: none (schema unchanged) | 634 → 660 | Local-FK delete rule (reject when local products/commission_dues reference the supplier, Arabic `ValidationException`, limitation documented); fixes: `writeSupplier` now mirrors+returns `commissionRate`, `updateSupplier` preserves `createdAt`; coordinator wiring copied from customers; `supplierWritesLocalFirstProvider` drives SnackBars; flush ordering proven for supplier→purchase→settle legs; no new migration; supplier sync badge out of scope |
| Phase 1B — employees master CRUD | *(this checkpoint 10/10)* | drift: none (schema unchanged) | 660 → 687 | Last Phase 1B domain (**phase complete**). Root cause of online-only writes: `employees_providers.dart` wired `OfflineEmployeeRepository` WITHOUT a coordinator + stale Slice-C coordinator methods (no tx, no `dependsOn`, update stomped `createdAt`, delete unguarded). Rewired all three (tx + `dependsOn` + `_employeeRow` createdAt-preserve); delete = local-FK rule on local salaries/employee_movements (not `stock_moves` — never mirrored, documented limitation); create→movement/create→salary ordering reused existing `_pendingLegIdsFor` (zero wiring); `employeeWritesLocalFirstProvider` drives SnackBars; employees read filter subtracts pending deletes; no new migration; employee sync badge out of scope |
| Phase 2 P0 — issue 6, cold-start data blackout | uncommitted | drift: none | 687 → 695 | Replaces the silent `NullLocalStore` degradation with a **loud-failure contract**: `openLocalStore` (`local_store.dart`) probes the schema (first query materializes `createAll`/`onUpgrade`), wraps ANY failure (corrupt file, failed migration, null native open) as `LocalStoreOpenException`, disposes the half-opened connection before rethrowing (desktop cannot delete an open sqlite file), and `app.dart` gates on `store.hasError` (Riverpod 3.4.3 surfaces a failed FutureProvider as `AsyncLoading`-with-error, so `when(error:)` never fires) → `LocalDataRepairScreen` (Arabic: Retry + destructive Reset behind a `ConfirmTone.danger` dialog, never auto-delete). Reset = injectable `resetLocalDatabaseProvider` seam (`offline_factory_io.dart`/`offline_factory_stub.dart` share `kLocalDatabaseFileName`); the screen disposes the live `DriftLocalStore` first, deletes the file, invalidates the provider. **Test-only fact:** `ProviderScope(retry: (_, _) => null)` is required in gate tests — Riverpod's default auto-retry re-invoked the throwing store factory mid-`pumpAndSettle` and flipped the gate to the login screen. Production keeps default auto-retry (a transient failure recovers on its own; the repair screen shows immediately on the first error). 3 new test files (restart durability, loud-open-failure, repair UI). No Supabase-side change |
| Phase 2 P2 — issues 1, 2 (invoice refreshed only when online) | uncommitted | none (drift unchanged) | 763 → 769 | **Both reported issues were one defect seen from two sides.** `_newInvoice` in both invoice screens called `listProvider.notifier.refresh()`, which correctly re-ran the list — but `pendingSyncCountProvider` and `invoiceSyncStatesProvider` read the **queue**, not the list, and nothing invalidated them, so the app claimed "everything synced" while the user's own unsent invoice sat in the list. Fix: `refreshAfterLocalInvoiceWrite(WidgetRef ref)` in `offline_sync_providers.dart` invalidates count + badge + both invoice lists, called by **both** screens. It takes a `WidgetRef` because the provider-side `Ref` used by `_refreshAfterDrain` cannot accept one, so the two helpers deliberately cannot be merged. The sale form's route result changed `String` → `({String no, bool pending})` to drive the pending SnackBar. **Both handoff hypotheses were wrong and the tests said so:** the list provider *was* refreshed (issue 1 was never a missing `_refreshAfterDrain` entry) and the merge *was* filter-aware. **Two false passes caught before shipping — both would have shipped a green suite over broken code.** (1) The sale row probe used `find.textContaining('D-')` and passed against the *unfixed* code: `InvoiceListView` renders only the **last three characters** (`_shortNo`), so the full number is never on screen and the finder was actually matching the **SnackBar**, which quotes the number — it would have passed with no row painted at all. Now derived from durable state. (2) With the purchase screen reverted to `.notifier.refresh()` the test still passed, for two independent reasons: a provider nobody read is rebuilt on first access, **and** these are autoDispose providers whose only listener (`InvoiceListView`) is not built while the list is empty, so the provider was disposed before the write. New `holdQueueProviders` reads **and** holds a `container.listen` open across the write. **Two assertions were corrected against real behaviour:** post-drain the badge map is *not* empty (`queueLegsFor` returns every leg; the drained one maps to `synced`, which is what makes the row unbadged), and awaiting a provider future inside `runAsync` **deadlocks** when the rebuild was triggered from that same `runAsync` — the harness settles in bounded real-timer rounds. **Test-only facts:** a purchase leg posts its credit to account **2010**, and a seed without it fails as `Required account not found in chart of accounts: 2010` with the form silently open on an inline error; the party name and `Money.format(total)` cell are the reliable row probes; `cacheLast` is still **network-first** (the A.5 flip applied to `cacheFirst` only), so a post-drain refetch does return the server row. **Mutation-proven four ways,** each failing a different assertion: drop the count invalidation, drop the badge invalidation, revert the purchase screen, un-branch the sale SnackBar. **Files:** `offline_sync_providers.dart`, `sale_invoices_screen.dart`, `purchase_invoices_screen.dart`, new `test/tool/offline_invoice_harness.dart` + `test/widget/offline_invoice_list_write_test.dart` (6 tests: sale row/badge/count/message, purchase inline-product + preserved product→invoice `dependsOn`, full container teardown, date-range filter, reconnect/drain to the official number, and a `HasadApp`→`AppShell`→`SaleInvoicesScreen` routing smoke). **No `data/` change, no migration, no RPC, no schema change. Phase 2 is complete.** |
| Phase 2 P1.C — corrective slice (mirror authority, double-submit, action lifecycle) | uncommitted | drift: none | 769 → 785 | Four defects, all in code P1 had just written. **Invoice reads never reached the mirror.** `OfflineInvoiceRepository` now ends every `list(type:)`/`list(status:)` with `_mirrorHeaders` → `LocalStore.mirrorInvoices` through `cacheLast(mirror:)`; the mirror is **header-only** (`requestId`/`createdAt` nulled, `synced = true`, `pendingMoneyLeg = null`) because `local_invoice_lines` is never mirrored. **`insertOrReplace` on an id-only primary key deletes a foreign tenant's row** — `local_invoices` is keyed `{id}` alone, so `ON CONFLICT DO UPDATE` matches on the key alone and a same-id row in another tenant is silently replaced; replaced by a tenant-scoped `delete` + plain `batch(insert)` in ONE transaction, so a foreign-tenant collision raises and rolls the whole mirror back. **A replayed invoice was mirrored twice**: `markReplaySynced` keeps the *local* id (the badge joins on the leg's `localId`) and records local→server in `id_map`, so the next online read saw the server's id as a different primary key; `mirrorInvoices` now resolves each incoming id through `localIdFor` and **updates the mapped row in place**. **A sheet could submit twice** (a disabled button is not a guard — two taps both land before the rebuild): all four submit paths take an imperative `if (_submitting) return;` plus `mounted` before catch-path `setState`. **And a valid submit threw an opaque error**: `PaymentActions`/`SalaryActions` are now `@Riverpod(keepAlive: true)` — a sheet only `ref.read`s them, and Riverpod 3 auto-disposes an unused action provider at the `await`, so the *next* call hit `UnmountedRefException`; **the sheets were opening and closing purely because of test-harness listeners**, and the three harnesses are now one-shot. **Bonus, P2's root cause:** the four money actions invalidate `pendingSyncCountProvider` themselves, gated on `result.pending == true`. **Mutation-proven:** `id_map` lookup stubbed to `null` (→ A1-I *and* the reconnect drain both fail on duplicates); `keepAlive` removed from `SalaryActions` (→ the race test fails via `SheetErrorBanner`) and from `PaymentActions` (→ all three payment/settlement cases); pending invalidation made unconditional (→ expected 1 / actual 5). **Still open:** Issue 4's device failure is still undiagnosed — an employee-movement phase trace across repository/coordinator/action/sheet was added in this slice, but it is **debug-only and silent in release**, so it must be captured from an instrumented build on the physical device before any behavioural fix (it was removed unused at the P1.G cleanup, having never produced a diagnosis) |
| Phase 2 P1.1 — durable leg→invoice attribution | uncommitted | drift: `sync_queue_items.affects_invoice_ids` (schema **7**, additive `< 7` migration, **no backfill**) | 746 → 763 | Closes P1's settlement residual: a `settle_supplier` leg is now attributed by a persisted invoice-id set instead of its (absent) `p_invoice_id` params, so a later money leg draining first can no longer retire a still-queued settlement's marker. `recordPayment` → `[row.id]`; `settleSupplier` → the `dueId == null` allocation invoice ids (due allocations touch commission dues, not invoice money). Written once in the same transaction as the local mutations. Resolver matches outstanding legs on tenant + attribution with a `p_invoice_id` fallback, ordered by `(createdAt, id)`. **Two mutation results changed the work rather than confirming it:** dropping the stamped half of the affected-set union passed the whole suite, so the reason that branch exists is documented in-code instead of asserted; and the union was previously unpinned in both directions until `resolution depends on the queue, not on which leg held the marker` was added. No backfill by design — a pre-v7 settlement's invoice set is unrecoverable (the server chose the allocation), so the residual is limited to legs queued at upgrade time and is self-healing once they drain. No Supabase-side change |
| Phase 2 P1 — issues 3, 4, 5 | uncommitted | drift: `local_invoices.pendingMoneyLeg` (schema **6**, additive `< 6` migration) | 695 → 746 | **Issue 3** (payments mis-recorded offline): the money figures an offline payment changes existed only in the local mirror, and replay marked the row `synced` without telling the merge layer, so the server value (which has the payment *before* the mirror) overwrote the corrected one. Fix is a **leg id, not a dirty flag** — `pendingMoneyLeg` is stamped with the same `legId` that the queue item carries, so two overlapping payments on one invoice stay distinguishable. The flusher retires the marker through `LocalStore.resolveInvoiceMoneyMarker`: for each invoice the drained leg stamped, the marker clears only when no other non-synced money leg for that invoice remains, and is otherwise re-stamped to the oldest such leg. Clearing on *this leg's* success alone was itself a bug — the marker names only the newest leg, so an out-of-order drain silently reverted the invoice. Known residual: leg→invoice attribution reads `p_invoice_id`, which a `settle_supplier` leg does not carry. Invoice authority is now: `synced == false` → local draft; `synced == true && marker != null` → server identity with local money; unmarked synced mirror → server only, never resurrected offline. Same marker gates the debts overlay (`_withPendingMoney` in `offline_statement_repository.dart`), which subtracts   unsynced `local_payments` per party because the server aggregate cannot know
  about them — but **a payment against an invoice that is itself an unsynced
  local draft is skipped**, because that invoice was never in the aggregate
  either, and subtracting it understates the debt. The debts overlay is applied
  to cached figures as well as live reads. **Issue 4** (movement/product-deduction failures explained only by a SnackBar, sheet already closed): all four sheets keep SnackBars for success and render `AppException.message` inline via the new reusable `SheetErrorBanner`; parsing moved *inside* the submit `try`. `_guard` maps engine `StateError` → `ValidationException(e.message)` **locally** — the global mapping was deliberately not broadened, since no reproduce justified it. **Issue 5** (salary double-pay guard vs the queue): the month guard is device-local, so a second payout in the same month must be refused offline too; the arithmetic moved to a pure `salary_computation.dart` (no Riverpod/Drift/Supabase) with `in`/`entitle` adding and `out`/`deduct`/unknown subtracting, `0 + 500` entitlement staying payable, and a zero-base month rejected in Arabic. No Supabase-side change. **Mutation evidence:** marker resolution forced back to "clear unconditionally" (→ only the out-of-order drain case), migration `addColumn` removed (→ 2 failures), debt overlay short-circuited (→ 5 failures), issue-4 failures reverted to SnackBars (→ movement + both payment-sheet tests), and the debts overlay's unsynced-draft filter disabled (→ only that one case) and widened to "invoice row present" (→ 4 cases) |
| Phase 2 P1.F.1 — open invoice's money stale after a payment | uncommitted | drift: none; Supabase: none (stays schema 8) | 880 → 882 | **A snapshot, not a missing refresh.** `PaymentActions._refresh()` already invalidated the invoice lists and the `pendingMoneyLeg` merge already made local money authoritative — both proven here. But both screens open the detail sheet as `builder: (_) => InvoiceDetailSheet(invoice: invoice)` and it **watched nothing**; a modal route is not rebuilt when its opener rebuilds, so the sheet above the list kept the frozen `paid`/`remaining`/`status` while the SnackBar quoted the correct new remaining (its only `FutureBuilder` was `ref.read`-ing `items(id)`, which refreshes lines, never the header). Fix is `_liveInvoice`: watch the **existing** list provider for `type` and resolve the row by the identity the list exposes — a second subscriber to one read that already runs for the list behind the sheet, so no added I/O, and `_merged` stays the single authority instead of being re-derived in the UI. All header/money reads moved to the resolved row, including the invoice handed to the payment sheet. **A dedicated single-invoice provider was rejected on purpose**: instant and filter-proof, but it needs a new repository method or a second copy of the `synced`/`pendingMoneyLeg` rule. `_RecordPaymentSheet` untouched (its submit already re-reads live remaining). Snapshot fallback on loading/error/not-found is deliberate and cannot be triggered by a payment (type/no/party/date are unchanged by one). New `test/widget/offline_payment_detail_refresh_test.dart` (2: sale + purchase) drives the real sheet and the real payment sheet and proves the **same mounted** sheet updates — no reopen, no manual invalidate, no container recreation, no delayed fake — pinning both transitions `100000/0` → 400 → `جزئية` + `40000/60000` → 600 → `مدفوعة` + `100000/0` with the button gone, asserting `listCalls` grew each time (so a pass cannot come from a first read) and checking the durable row at every step. Probes are label+value pairs because a paid-off invoice renders `المدفوع` and `الإجمالي` identically. **Mutation:** reverting only the resolution fails both cases at the first post-payment money assertion with `Expected: '400'` / `Actual: '0'` — the device symptom reproduced. Two test-only traps recorded: `_canPay` `ref.read`s auth at build time so the auth graph must be settled before the sheet opens, and `Text`'s element is a `StatelessElement` (cast `.widget`, not the element). Verification: analyze clean, **882/882**, web release + Arabic green (268.7s), debug APK green (95.1s), byte-level UTF-8 clean. The employee-movement diagnostic trace was still present at this point and was removed unused in the P1.G cleanup |
| Phase 2 P1.G — a replayed invoice's lines erased by its own detail read | uncommitted | drift: none; Supabase: none (stays schema 8) | 882 → 891 | **Two independent defects, both reachable only after an offline create is replayed, both reported as "the invoice lines disappeared".** (1) *P1.F.1's reactive header is what exposed this*: `markReplaySynced` keeps the **local** id and records `id_map(L→S)`, so durable lines live under `L` while the merged list exposes `S` — and the one field P1.F.1 did **not** convert, the line read, still used the captured id. (2) *A successful empty read destroyed the data*: `cacheLast` returns the server's `[]`, and `items()` mirrored it through `mirrorInvoiceItems`, which is replace-all in one transaction — a green, non-erroring read deleting every durable line. Fix 1: `items()` now resolves the inverse mapping (`remoteId = serverIdFor(...) ?? id`), sends `remoteId` to the network and keys the cache `invItems:$remoteId`, so a detail read through **either** id space reaches the server; normalizing in the data layer also keeps `id_map` out of the presentation layer. **The requested `items(live.id)` fix was reverted as a provable no-op** — `_liveInvoice` returns a row only on `row.id == captured.id`, so `live.id == invoice.id` by construction — and **M1 SURVIVED (9/9 passed under the revert)**; recorded, not hidden, per P1.1's rule that a surviving mutation gets pinned or written down. Fix 2: an empty answer now returns `_localItems(t, localId)` and skips the mirror. **`[]` is non-authoritative for invoice lines because creation forbids zero lines** (`0007`:136-138, `0008`:68-69 both raise on empty `p_items`), so an empty detail answer can only be a read artifact — **never mirror `[]` over known durable lines**. This **narrows, not reverses**, P1.E's "a cached `[]` is a legitimate answer" (still true for a genuinely empty invoice; it may no longer *delete* to get there). Non-empty detail stays authoritative and is the **repair** path — replace-all is how an already-erased device recovers without Clear Data. Tests 882 → 891 (+9): R1/R2/R5-sale/R5-purchase in new `test/widget/invoice_detail_items_identity_test.dart` (drives the real sheet; the same mounted sheet keeps its lines across replay, and the read reaches the network under `S`), plus R3/R4/R6/control/R7 in new `test/data/offline/offline_invoice_items_empty_mirror_test.dart`. **R7 is the reason the slice matters**: it seeds the real replayed shape, erases the lines under `L` with a direct `mirrorInvoiceItems(L, [])` to reproduce the damage, then reads through the normal `S` path and asserts recovery in-process **and after closing/reopening the same file-backed database** — no-Clear-Data recovery for already-damaged local detail, with no schema change. Control keeps the non-empty authoritative case pinned. **Mutation results:** M2 (drop the empty guard) kills R6+R3 while R5 stays green; M3 (drop non-empty hydration) kills R7+control while R6 stays green; **M1 survives** for the reason above. Harness additions: `OfflineInvoiceHarness.adopt`, an optional `invoiceRepository` seam on `harnessHost`, `secondProductId`/`secondProductName`, and `itemsById`/`itemsCalls` on the fake network. Verification: analyze clean (51.0s), focused R1-R7+control 9/9, durability/migration/batch/payment/pending suites 72/72, offline write+replay 163/163, `flutter test --no-pub` **891/891**, `flutter build web --release --dart-define=use_arabic=true` green (178.9s), `flutter build apk --debug` green (211,037,009 bytes), byte-level UTF-8 clean (0 U+FFFD on all 5 touched files). **Final post-cleanup verification:** the temporary movement trace and `lib/core/diagnostics/` were removed first, then everything re-ran green — analyze clean (141.2s), movement-focused suites 101/101, P1.G detail+empty-mirror 11/11, durability/migration/batch/payment/pending 136/136, offline write+flush 139/139, `flutter test --no-pub` **891/891**, `flutter build web --release --dart-define=use_arabic=true` green (215.8s), `flutter build apk --debug` green (211,034,089 bytes), byte-level UTF-8 clean across all 17 touched files, and **zero** occurrences of the movement trace's marker or any of its type names anywhere in `lib/` or `test/` (its removal is asserted by the absence of the symbols, so no literal marker is repeated here either). **Device recovery PASSED** (2026-10-02): the user re-read the already-damaged invoice **over existing app data with no Clear Data**, its lines returned on the online read and survived a force-close plus an offline re-read. The transient duplicate invoice was not reproduced on the device or deterministically, so no speculative `_merged` fix was made |
| Phase 2 P1.E — corrective slice (invoice lines not durable, ordered, or tenant-safe) | uncommitted | drift: `local_invoice_items` PK → `{tenantId, id}` (schema **8**, table rebuild, **no backfill**) | 819 → 849 | P1.C made the header authoritative and P1.D made listed invoices resolvable; the **lines** were left behind by both. `local_invoice_items` carried the same `{id}`-only key as `local_invoices` while every writer used `insertOrReplace`, so mirroring one workspace's lines for a shared invoice id silently replaced the other workspace's rows — schema 8 moves `tenant_id` into the key (`local_invoices`/`local_suppliers` deliberately unchanged; no schema-wide invariant exists). `LocalStore.invoiceLineId` mints positional ids **zero-padded to 4 digits** used by both pending writers — load-bearing, since unpadded `ORDER BY id` sorts `:10` before `:2`, invisible at 9 lines and wrong at 10. `mirrorInvoiceItems` replaces the whole set in one transaction (so an empty `[]` refresh clears), refuses to sweep an **unsynced** header, and is tenant-scoped on delete and read. `items()` resolves the server id through `localIdFor` first (P1.D's rule applied to lines); an unsynced draft bypasses `cacheLast`, a synced invoice follows the final network/cache value, and a cached `[]` is a legitimate wipe. Legacy bare-uuid line ids stay readable and are **never rewritten** — the original ordinal was never recorded, so original order is unrecoverable for pre-v8 rows and is documented, not faked. **The migration has no missing-table guard**, matching P1.1's fixture rule: the table has existed since schema 1, so a file without it is corrupt, and a guard would turn corruption into a *successful* upgrade with an empty table — two existing fixtures omitted the table and **the fixtures were corrected instead**. New `test/data/offline/invoice_items_key_migration_test.dart` (4) reads each fixture's own DDL back out of `sqlite_master` to pin the shape it upgrades from, and is **mutation-proven both ways**: dropping the re-insert fails row survival; making the rebuild a no-op fails with `UNIQUE constraint failed: local_invoice_items.id`, i.e. the defect itself. No Supabase-side change |
| Phase 2 P1.F — list-time line hydration, mapped-row money authority, search, validation order | uncommitted | drift: none; Supabase: none (stays schema 8) | 849 → 880 | **P1.E made the lines durable only for the invoice the user OPENED** — `mirrorInvoiceItems` is written by `items(id)`, so a device that listed twenty invoices and opened none had headers and no lines, which is the state a list actually leaves behind. `OfflineInvoiceRepository.list` now ends with `_prefetchDetails(merged)` after `_mirrorHeaders` (the header write is what makes the lines keyable, and `mirrorInvoiceItems` refuses to sweep an unsynced header). **The obvious fix is the forbidden one:** a loop of `items(id)` is N+1, fails halfway, and — because `items(id)` cache-lasts per invoice — would re-ask for everything on EVERY refresh including offline ones. Candidates are narrowed by **one** bulk local query, `LocalStore.invoiceIdsWithDurableItems` (single `selectOnly` + `groupBy`, tenant-scoped), and the 100-id chunking lives **inside** `InvoiceRepository`, never in the caller. **`InvoiceItemsBatch` exists because "answered with nothing" ≠ "not answered":** a present `[]` key is authoritative and may clear a synced invoice's lines; a `failed` id leaves its durable rows untouched — collapsing the two makes every failed read erase its lines. The prefetch resolves the id space on **both** sides: `invoiceIdsWithDurableItems` maps candidates internally (one `isIn` read, then one grouped scan) so a replayed invoice whose lines are already durable is not re-requested on every refresh, and each successful answer is re-keyed through `localIdFor` so it cannot get a **second** line set beside the local one. Resolving it at the call site instead would have been one extra query per invoice — the N+1 relocated, not removed. A `NetworkException` is swallowed (the header list must not depend on optional hydration); the drift lookup and mirror stay outside the `try` for P1.D's reason. **A mapped row's money AND marker were both being overwritten:** `mirrorInvoices` filtered **server** ids against a set of **local** ids, so a row this device minted never compared equal, fell through to the update branch, and had the server's pre-payment money written over the local correction with the marker cleared in the same statement; every incoming id is now resolved to its effective local id up front and both the filter and the update consume it. **The product picker's search box was inert** — it is the only writer of `productSearchProvider` and it watched the provider that never reads it; now watches `productsListProvider` (reopen works because it is `autoDispose`). **No `excludeIds`** in either direction; duplicate selection stays characterized. **`writeSale`'s honest Arabic refusal was dead code** — the unknown-product check sat after the comprehension that dereferences `products[id]!` for the default price, so the `!` threw first; validation now runs first over `draft.lines`, with **no broadened `TypeError` mapping**, and `writePurchase` is marked as the reference shape it already was. **Two test defects, both "green suite over broken code":** `sheet_inline_error_test.dart` stubbed `allProductsProvider`, which the picker stopped reading (it now stubs `productRepositoryProvider`), and A3's `singleInvoiceCalls`-empty assertion would pass for a loop of `itemsForInvoices([id])`, so the **exact id set of each call** is asserted. **A7/A7b then pinned the cost side nobody had covered:** A7 seeds the real replayed shape (synced header under a local uuid, lines under that same local id, a `local → server` mapping) and asserts the batch asks only for the two invoices with nothing durable; A7b lists twice and asserts the second refresh issues **zero** detail requests, offline. Before them an implementation that re-fetched every invoice forever still passed the whole suite. **Mutation results:** M1 (raw server id in `mirrorInvoices`) was killed by **C7**, not C3/C5 — the over-protection guard is what catches the id-space slip, the opposite of the prediction; M2 killed B1 **and** B1.3; M3 killed A1/A2/A3; M4 (N single reads) killed A1/A2/A3; M5 killed B4.3 with a raw `TypeError`; M6 (mapping resolved to itself in the durable check) killed **A7 only**, leaving A7b green — the two cost cases fail independently. All reverted before the final run. **Zero-line invoices are re-asked on a later list** — no completeness metadata, accepted and documented. Verification: analyze clean, `flutter test --no-pub` **880/880**, `flutter build web --dart-define=use_arabic=true` green, `flutter build apk --debug` green, byte-level UTF-8 scan clean across `lib/` and `test/`. **Device check **PASSED** on the physical device (2026-10-01): the hydrated detail body, the picker search (online and offline), the Arabic unknown-product validation, payment durability across refresh/restart, and reconnect→drain→restart with no duplicate. The one thing that device pass did **not** cover was the money shown immediately after a payment — that is the P1.F.1 defect below, fixed and automated, and **confirmed on the device by the follow-up pass (2026-10-02)**: the already-mounted detail sheet showed the new paid/remaining figures with no reopen and no manual invalidate |
| Phase 2 P1.D — corrective slice (cached invoice not resolvable; paid month read as payable) | uncommitted | drift: none; Supabase: none | 785 → 819 | **A cached invoice was visible but unwritable.** `cacheLast` has no success/failure signal, so it cannot be the thing that hydrates and the generic helper was left alone; `OfflineInvoiceRepository` ends the cached path with `_mirrorHeaders(merged)` on the **final merged list** (the invoice-specific `mirror:` callback only runs on the network branch, which is the path that already worked). **The wider half of the defect was a mapped id:** `markReplaySynced` keeps the *local* uuid (the badge joins on the leg's `localId`) and records local→server in `id_map`, so a replayed invoice is stored under one id, served under another, and `_invoice` resolved only by exact local id — every money write against it was refused. Now falls back to the tenant/entity-scoped `localIdFor`; `settleSupplier` needed nothing because it resolves invoices by `partyId`, never by id. **The P1.C collision rule was reversed deliberately:** a cross-tenant same-id collision is now **skipped and its safe siblings written**, not raised — raising rolls the whole transaction back, so one colliding uuid would leave nineteen siblings unhydrated, i.e. the original defect one level down. It is the one documented exception to "anything `list()` returns is resolvable". Hydration errors are **not** wrapped in `try/catch`; a genuine drift failure must not be reported as a successful read whose invoices silently do not resolve. **A paid month read as payable:** `netDue` is the month's entitlement and must not shrink (zeroing it also corrupts the arrears base), so `EmployeeEntitlement` gained a **required** `isPaidForMonth` and a derived `currentPayable`; the screen's gross is relabelled `استحقاق الشهر`, the payable is `المتبقي للصرف`, `canPay` gates on `currentPayable`, and the pay sheet defaults/caps on it. `OfflineSalaryRepository` composes `serverPaid \|\| localPaid` (disjoint windows: pre-drain only the local row knows, post-drain only the server does on a cleared device) and reads the paid state from **the same rows** the figures came from. `SupabaseSalaryRepository` adds a narrow `salaries` existence query — no new RPC. Month formats are now `salaryMonthKey` (`yyyy-MM`, local) / `salaryMonthDate` (`yyyy-MM-01`, server); `offline_write._monthKey` was building a third copy. **`SalaryActions.pay` re-reads the live entitlement**: the coordinator's dup-month guard is device-local (`local_salaries`), so on a cleared or offline device it would queue a second payout for a month the server already holds. **Three test defects found and fixed, all of the "green suite over broken code" kind:** the tenant-isolation case asserted an **unreachable** state (it asked tenant A for tenant B's employee, but `LocalEmployees` is keyed `{id}` alone, so the read correctly *throws*); the post-pay case asserted `find.text('5000')`, which matches **twice** before a payout and still matches the gross alone after the relabel, so it passed against a half-fix; and the dynamic `(ent as dynamic).isPaidForMonth` probes swallowed a missing member into "unpaid", indistinguishable from the bug being pinned. **Mutation-proven seven ways, each failing a distinct assertion:** hydration removed (→ 10 invoice cases), `localIdFor` fallback → `null` (→ C1b), unsynced/money protection dropped (→ D1 **and** D2), foreign-id partition emptied (→ D4a/b/c), local paid → `false` (→ S2a/S2c/S4a/S5a/S7a), server half of the `\|\|` dropped (→ S3a **only**), `canPay` → `netDue` (→ the widget case **only**). The stale-sheet guard needed a **new** test to have teeth: the existing race and inline-error suites stayed green with it removed, because both drive a repository whose `entitlement` never changes — the fake now carries a mutable paid flag so the state can move while the sheet is open. Verification: analyze clean, `flutter test --no-pub` **819/819**, web build green (167.7s), `flutter build apk --debug` green (131.6s), byte-level encoding check clean on all 14 touched files. **Device smoke PASSED** (2026-10-02) for the salary path: recording and paying ran on the physical device. Note the scope honestly — this is a functional smoke, so the paid-month card's Cairo-font rendering still has no human visual audit |
