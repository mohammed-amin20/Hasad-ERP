// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the dashboard summary from Supabase. Override in tests with a fake.

@ProviderFor(dashboardRepository)
final dashboardRepositoryProvider = DashboardRepositoryProvider._();

/// Reads the dashboard summary from Supabase. Override in tests with a fake.

final class DashboardRepositoryProvider
    extends
        $FunctionalProvider<
          DashboardRepository,
          DashboardRepository,
          DashboardRepository
        >
    with $Provider<DashboardRepository> {
  /// Reads the dashboard summary from Supabase. Override in tests with a fake.
  DashboardRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardRepositoryHash();

  @$internal
  @override
  $ProviderElement<DashboardRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DashboardRepository create(Ref ref) {
    return dashboardRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DashboardRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DashboardRepository>(value),
    );
  }
}

String _$dashboardRepositoryHash() =>
    r'5007b1317808745a70e27da7bd60efde526d5d08';

/// Fetches the dashboard summary once. Invalidate to reload.

@ProviderFor(DashboardSummaryNotifier)
final dashboardSummaryProvider = DashboardSummaryNotifierProvider._();

/// Fetches the dashboard summary once. Invalidate to reload.
final class DashboardSummaryNotifierProvider
    extends $AsyncNotifierProvider<DashboardSummaryNotifier, DashboardSummary> {
  /// Fetches the dashboard summary once. Invalidate to reload.
  DashboardSummaryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardSummaryNotifierHash();

  @$internal
  @override
  DashboardSummaryNotifier create() => DashboardSummaryNotifier();
}

String _$dashboardSummaryNotifierHash() =>
    r'6dde69e2e9af2e1603de13895a2fa0b93aee97b7';

/// Fetches the dashboard summary once. Invalidate to reload.

abstract class _$DashboardSummaryNotifier
    extends $AsyncNotifier<DashboardSummary> {
  FutureOr<DashboardSummary> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<DashboardSummary>, DashboardSummary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DashboardSummary>, DashboardSummary>,
              AsyncValue<DashboardSummary>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
