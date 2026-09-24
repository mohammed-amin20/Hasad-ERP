import 'dart:async';

import '../../core/error/app_exception.dart';
import 'local_store.dart';

/// Offline-first read policy shared by every data-repository wrapper (Slice B).
///
/// **Cache-first (M11 Slice A.5):** serve the local mirror immediately for a
/// verdict-free read, fan out the live network read in the background, mirror
/// on success, and NEVER gate reads on the connectivity verdict — that verdict
/// drives the write/retry UI (`retry_widgets.dart`), not the read path. When
/// the local store is absent (web) or the tenant is unstamped (pre-0023), the
/// read never consults connectivity: it degrades to a plain live read. An
/// empty/absent mirror combined with an unreachable remote surfaces an honest
/// error instead of a silent `[]`.
///
/// `mirror` and `local` are invoked only when [store] and [tenantId] are
/// non-null, so web (a no-op local store) degrades to a normal network repo.
Future<T> cacheFirst<T>({
  required LocalStore? store,
  required String? tenantId,
  required Future<T> Function() network,
  required Future<T> Function() local,
  Future<void> Function(T value)? mirror,
}) async {
  final s = store;
  final t = tenantId;
  // Web (no local store) or unstamped tenant → no mirror exists; serve the
  // live read directly. The connectivity verdict is write/retry UI wiring,
  // never consulted here.
  if (s == null || t == null) return network();

  Future<T> live() async {
    final fresh = await network();
    final m = mirror;
    if (m != null) {
      try {
        await m(fresh);
      } on Object {
        // Never fail a successful read because the mirror write failed.
      }
    }
    return fresh;
  }

  // Serve the mirror immediately (cache-first). A null result, or an empty
  // list mirror (masters listAll), means there is no usable local data — fall
  // through to the live read instead of silently returning empty.
  T? served;
  try {
    served = await local();
  } on Object {
    served = null;
  }
  if (served != null && !(served is Iterable && (served as Iterable).isEmpty)) {
    // Mirror served. Refresh in the background — best-effort, mirror on
    // success, and NEVER allowed to fail the already-served read.
    unawaited(() async {
      try {
        await live();
      } on Object {
        // Background refresh is best-effort; the mirror was already served.
      }
    }());
    return served;
  }

  // Empty/absent mirror: try the live read. If the remote is unreachable,
  // rethrow the NetworkException — honesty over a silent [].
  try {
    return await live();
  } on NetworkException {
    try {
      final again = await local();
      if (again != null && !(again is Iterable && (again as Iterable).isEmpty)) {
        return again;
      }
    } on Object {
      // fall through to the honest rethrow
    }
    rethrow;
  }
}

/// Cache-last-success variant for report-style reads: the network result is
/// serialized under [key] in `report_cache` and rehydrated from it on a
/// [NetworkException]. Online it returns fresh data (and refreshes the cache);
/// offline it returns the last successful payload; with no cache yet it
/// rethrows so callers can show a retry state.
Future<T> cacheLast<T>({
  required LocalStore? store,
  required String? tenantId,
  required String key,
  required Future<T> Function() network,
  required T Function(String payload) fromCached,
  required String Function(T value) toPayload,
}) async {
  final T value;
  try {
    value = await network();
  } on NetworkException {
    final s = store;
    final t = tenantId;
    if (s != null && t != null) {
      final cached = await s.report(t, key);
      if (cached != null) return fromCached(cached);
    }
    rethrow;
  }
  final s = store;
  final t = tenantId;
  if (s != null && t != null) {
    try {
      await s.putReport(t, key, toPayload(value));
    } on Object {
      // Never fail a successful live read because caching failed.
    }
  }
  return value;
}

/// Local `yyyy-MM-dd` date string, matching the RPC `_isoDate` helpers.
String cacheDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
