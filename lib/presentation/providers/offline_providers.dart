import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/offline/local_store.dart';
import 'auth_providers.dart';

part 'offline_providers.g.dart';

/// Resolves the current tenant id (null until the session load settles).
@riverpod
String? currentTenantId(Ref ref) => ref.watch(authStateProvider).value?.tenantId;

/// Resolves the opened local store (null on web or while opening).
@riverpod
LocalStore? localStoreBox(Ref ref) => ref.watch(localStoreProvider).value;

/// Last-succesful-fetch time of the cached report under [key], or null when
/// it was never cached (drives the freshness indicator).
@riverpod
Future<DateTime?> reportCachedAt(Ref ref, String key) async {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  if (store == null || tenantId == null) return null;
  final data = await store.cachedReport(tenantId, key);
  return data?.fetchedAt;
}