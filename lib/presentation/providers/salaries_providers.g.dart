// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salaries_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salaryRepository)
final salaryRepositoryProvider = SalaryRepositoryProvider._();

final class SalaryRepositoryProvider
    extends
        $FunctionalProvider<
          SalaryRepository,
          SalaryRepository,
          SalaryRepository
        >
    with $Provider<SalaryRepository> {
  SalaryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salaryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salaryRepositoryHash();

  @$internal
  @override
  $ProviderElement<SalaryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SalaryRepository create(Ref ref) {
    return salaryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SalaryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SalaryRepository>(value),
    );
  }
}

String _$salaryRepositoryHash() => r'4abad2dce5eafeee4b9f368cee96dec11dc9d920';

/// Entitlement preview for one employee+month, recomputed after any write.

@ProviderFor(SalaryRun)
final salaryRunProvider = SalaryRunFamily._();

/// Entitlement preview for one employee+month, recomputed after any write.
final class SalaryRunProvider
    extends $AsyncNotifierProvider<SalaryRun, EmployeeEntitlement> {
  /// Entitlement preview for one employee+month, recomputed after any write.
  SalaryRunProvider._({
    required SalaryRunFamily super.from,
    required (String, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'salaryRunProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$salaryRunHash();

  @override
  String toString() {
    return r'salaryRunProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SalaryRun create() => SalaryRun();

  @override
  bool operator ==(Object other) {
    return other is SalaryRunProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$salaryRunHash() => r'33e71599c7485b0b6393e13bac970bdd6c7bcb51';

/// Entitlement preview for one employee+month, recomputed after any write.

final class SalaryRunFamily extends $Family
    with
        $ClassFamilyOverride<
          SalaryRun,
          AsyncValue<EmployeeEntitlement>,
          EmployeeEntitlement,
          FutureOr<EmployeeEntitlement>,
          (String, DateTime)
        > {
  SalaryRunFamily._()
    : super(
        retry: null,
        name: r'salaryRunProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Entitlement preview for one employee+month, recomputed after any write.

  SalaryRunProvider call(String employeeId, DateTime month) =>
      SalaryRunProvider._(argument: (employeeId, month), from: this);

  @override
  String toString() => r'salaryRunProvider';
}

/// Entitlement preview for one employee+month, recomputed after any write.

abstract class _$SalaryRun extends $AsyncNotifier<EmployeeEntitlement> {
  late final _$args = ref.$arg as (String, DateTime);
  String get employeeId => _$args.$1;
  DateTime get month => _$args.$2;

  FutureOr<EmployeeEntitlement> build(String employeeId, DateTime month);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EmployeeEntitlement>, EmployeeEntitlement>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EmployeeEntitlement>, EmployeeEntitlement>,
              AsyncValue<EmployeeEntitlement>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

/// Paid-salary rows for the tenant, refreshed after any salary write.

@ProviderFor(salaryHistory)
final salaryHistoryProvider = SalaryHistoryProvider._();

/// Paid-salary rows for the tenant, refreshed after any salary write.

final class SalaryHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SalaryRecord>>,
          List<SalaryRecord>,
          FutureOr<List<SalaryRecord>>
        >
    with
        $FutureModifier<List<SalaryRecord>>,
        $FutureProvider<List<SalaryRecord>> {
  /// Paid-salary rows for the tenant, refreshed after any salary write.
  SalaryHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salaryHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salaryHistoryHash();

  @$internal
  @override
  $FutureProviderElement<List<SalaryRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SalaryRecord>> create(Ref ref) {
    return salaryHistory(ref);
  }
}

String _$salaryHistoryHash() => r'e2cc9cb8fc1e59aa3ed7ecccbd865035d36c1a4d';

/// Per-month salary statement for one employee over a month range.

@ProviderFor(employeeStatement)
final employeeStatementProvider = EmployeeStatementFamily._();

/// Per-month salary statement for one employee over a month range.

final class EmployeeStatementProvider
    extends
        $FunctionalProvider<
          AsyncValue<EmployeeStatement>,
          EmployeeStatement,
          FutureOr<EmployeeStatement>
        >
    with
        $FutureModifier<EmployeeStatement>,
        $FutureProvider<EmployeeStatement> {
  /// Per-month salary statement for one employee over a month range.
  EmployeeStatementProvider._({
    required EmployeeStatementFamily super.from,
    required EmployeeStatementRequest super.argument,
  }) : super(
         retry: null,
         name: r'employeeStatementProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$employeeStatementHash();

  @override
  String toString() {
    return r'employeeStatementProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EmployeeStatement> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EmployeeStatement> create(Ref ref) {
    final argument = this.argument as EmployeeStatementRequest;
    return employeeStatement(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EmployeeStatementProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$employeeStatementHash() => r'd092925ca4508e3b0afdeaf41e0abd38063356aa';

/// Per-month salary statement for one employee over a month range.

final class EmployeeStatementFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<EmployeeStatement>,
          EmployeeStatementRequest
        > {
  EmployeeStatementFamily._()
    : super(
        retry: null,
        name: r'employeeStatementProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-month salary statement for one employee over a month range.

  EmployeeStatementProvider call(EmployeeStatementRequest request) =>
      EmployeeStatementProvider._(argument: request, from: this);

  @override
  String toString() => r'employeeStatementProvider';
}

/// Executes movement/salary actions, then refreshes the entitlement preview
/// and any inventory-dependent lists (a `product` deduction moves stock).

@ProviderFor(SalaryActions)
final salaryActionsProvider = SalaryActionsProvider._();

/// Executes movement/salary actions, then refreshes the entitlement preview
/// and any inventory-dependent lists (a `product` deduction moves stock).
final class SalaryActionsProvider
    extends $NotifierProvider<SalaryActions, Object?> {
  /// Executes movement/salary actions, then refreshes the entitlement preview
  /// and any inventory-dependent lists (a `product` deduction moves stock).
  SalaryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salaryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salaryActionsHash();

  @$internal
  @override
  SalaryActions create() => SalaryActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Object? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Object?>(value),
    );
  }
}

String _$salaryActionsHash() => r'036c441e0da85164559944137d7c703320442038';

/// Executes movement/salary actions, then refreshes the entitlement preview
/// and any inventory-dependent lists (a `product` deduction moves stock).

abstract class _$SalaryActions extends $Notifier<Object?> {
  Object? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Object?, Object?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Object?, Object?>,
              Object?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
