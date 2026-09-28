// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The concrete repository wired at the composition root.
///
/// Wrapped in [OfflineAwareAuthRepository] so a cold start with no network
/// restores the last-known profile from the local store instead of failing the
/// `users` read and dropping the user on the login screen. The decorator needs
/// the already-open store, so it is awaited here — this provider is only read
/// by [authState]/[availableTenants], neither of which participates in the
/// store's own provider graph, so there is no cycle.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// The concrete repository wired at the composition root.
///
/// Wrapped in [OfflineAwareAuthRepository] so a cold start with no network
/// restores the last-known profile from the local store instead of failing the
/// `users` read and dropping the user on the login screen. The decorator needs
/// the already-open store, so it is awaited here — this provider is only read
/// by [authState]/[availableTenants], neither of which participates in the
/// store's own provider graph, so there is no cycle.

final class AuthRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AuthRepository>,
          AuthRepository,
          FutureOr<AuthRepository>
        >
    with $FutureModifier<AuthRepository>, $FutureProvider<AuthRepository> {
  /// The concrete repository wired at the composition root.
  ///
  /// Wrapped in [OfflineAwareAuthRepository] so a cold start with no network
  /// restores the last-known profile from the local store instead of failing the
  /// `users` read and dropping the user on the login screen. The decorator needs
  /// the already-open store, so it is awaited here — this provider is only read
  /// by [authState]/[availableTenants], neither of which participates in the
  /// store's own provider graph, so there is no cycle.
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AuthRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AuthRepository> create(Ref ref) {
    return authRepository(ref);
  }
}

String _$authRepositoryHash() => r'ca16e886f786ed4f6a3f3d1276524b50e7c69a8d';

/// Stream of the current signed-in user (null when signed out).
///
/// An `async*` generator rather than a direct delegation so it can await the
/// offline-aware repository: that decorator must be constructed with the
/// already-open [LocalStore], and awaiting here means the stream's *first*
/// emission is the cached profile on an offline cold start.

@ProviderFor(authState)
final authStateProvider = AuthStateProvider._();

/// Stream of the current signed-in user (null when signed out).
///
/// An `async*` generator rather than a direct delegation so it can await the
/// offline-aware repository: that decorator must be constructed with the
/// already-open [LocalStore], and awaiting here means the stream's *first*
/// emission is the cached profile on an offline cold start.

final class AuthStateProvider
    extends
        $FunctionalProvider<AsyncValue<AppUser?>, AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
  /// Stream of the current signed-in user (null when signed out).
  ///
  /// An `async*` generator rather than a direct delegation so it can await the
  /// offline-aware repository: that decorator must be constructed with the
  /// already-open [LocalStore], and awaiting here means the stream's *first*
  /// emission is the cached profile on an offline cold start.
  AuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  $StreamProviderElement<AppUser?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AppUser?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'9ae923556607b331824ffcdcd05a5c6106cd5e96';

/// Fetch all tenants the current user has access to.

@ProviderFor(availableTenants)
final availableTenantsProvider = AvailableTenantsProvider._();

/// Fetch all tenants the current user has access to.

final class AvailableTenantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TenantRef>>,
          List<TenantRef>,
          FutureOr<List<TenantRef>>
        >
    with $FutureModifier<List<TenantRef>>, $FutureProvider<List<TenantRef>> {
  /// Fetch all tenants the current user has access to.
  AvailableTenantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableTenantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableTenantsHash();

  @$internal
  @override
  $FutureProviderElement<List<TenantRef>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TenantRef>> create(Ref ref) {
    return availableTenants(ref);
  }
}

String _$availableTenantsHash() => r'e1c2d8ed8b8f46f56fe8e3b55adf1cda606e8d0d';

/// Tenant switch action — switches the current tenant and invalidates all dependent providers.

@ProviderFor(TenantSwitch)
final tenantSwitchProvider = TenantSwitchProvider._();

/// Tenant switch action — switches the current tenant and invalidates all dependent providers.
final class TenantSwitchProvider
    extends $AsyncNotifierProvider<TenantSwitch, void> {
  /// Tenant switch action — switches the current tenant and invalidates all dependent providers.
  TenantSwitchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tenantSwitchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tenantSwitchHash();

  @$internal
  @override
  TenantSwitch create() => TenantSwitch();
}

String _$tenantSwitchHash() => r'2c553392f306522f6bdce0d6e4df373627bec3fa';

/// Tenant switch action — switches the current tenant and invalidates all dependent providers.

abstract class _$TenantSwitch extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
