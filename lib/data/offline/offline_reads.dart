import '../../core/error/app_exception.dart';
import 'local_store.dart';

/// Offline-first read policy shared by every data-repository wrapper (Slice B).
///
/// Always try the live network read first, then mirror the fresh result into
/// the local store (best-effort — a mirroring failure never fails the read).
/// Only when the network read raises [NetworkException] do we serve the local
/// mirror; with no local data the original error propagates so the UI can
/// offer a retry.
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
  final T value;
  try {
    value = await network();
  } on NetworkException {
    return local();
  }
  final s = store;
  final t = tenantId;
  if (s != null && t != null && mirror != null) {
    try {
      await mirror(value);
    } on Object {
      // Never fail a successful live read because the mirror write failed.
    }
  }
  return value;
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