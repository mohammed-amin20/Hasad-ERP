// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The concrete repository wired at the composition root.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// The concrete repository wired at the composition root.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// The concrete repository wired at the composition root.
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
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'2671ff3f02f0ba17717afa46fe03702ec2e9c5a7';

/// Stream of the current signed-in user (null when signed out).

@ProviderFor(authState)
final authStateProvider = AuthStateProvider._();

/// Stream of the current signed-in user (null when signed out).

final class AuthStateProvider
    extends
        $FunctionalProvider<AsyncValue<AppUser?>, AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
  /// Stream of the current signed-in user (null when signed out).
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

String _$authStateHash() => r'28289662db95e3db4c5bd3165b78ad16cb8b8f70';

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

String _$availableTenantsHash() => r'462dce77f357ee1c9fe82775467615e2eb615904';

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

String _$tenantSwitchHash() => r'511d9d840dfc7408acd9beb63f6edba2b071ed05';

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
