// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'employees_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Concrete employee repository wired to Supabase.

@ProviderFor(employeeRepository)
final employeeRepositoryProvider = EmployeeRepositoryProvider._();

/// Concrete employee repository wired to Supabase.

final class EmployeeRepositoryProvider
    extends
        $FunctionalProvider<
          EmployeeRepository,
          EmployeeRepository,
          EmployeeRepository
        >
    with $Provider<EmployeeRepository> {
  /// Concrete employee repository wired to Supabase.
  EmployeeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'employeeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$employeeRepositoryHash();

  @$internal
  @override
  $ProviderElement<EmployeeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmployeeRepository create(Ref ref) {
    return employeeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmployeeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmployeeRepository>(value),
    );
  }
}

String _$employeeRepositoryHash() =>
    r'317ef563a4e1ad7058384bd86c8bdb24d2c7f572';

/// Current search term for the employee list (reactive).

@ProviderFor(EmployeeSearch)
final employeeSearchProvider = EmployeeSearchProvider._();

/// Current search term for the employee list (reactive).
final class EmployeeSearchProvider
    extends $NotifierProvider<EmployeeSearch, String> {
  /// Current search term for the employee list (reactive).
  EmployeeSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'employeeSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$employeeSearchHash();

  @$internal
  @override
  EmployeeSearch create() => EmployeeSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$employeeSearchHash() => r'182731b7beac79927394f1c656958ab52b814e82';

/// Current search term for the employee list (reactive).

abstract class _$EmployeeSearch extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Full unfiltered employee list (for dropdowns/pickers), never search-filtered.

@ProviderFor(allEmployees)
final allEmployeesProvider = AllEmployeesProvider._();

/// Full unfiltered employee list (for dropdowns/pickers), never search-filtered.

final class AllEmployeesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Employee>>,
          List<Employee>,
          FutureOr<List<Employee>>
        >
    with $FutureModifier<List<Employee>>, $FutureProvider<List<Employee>> {
  /// Full unfiltered employee list (for dropdowns/pickers), never search-filtered.
  AllEmployeesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allEmployeesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allEmployeesHash();

  @$internal
  @override
  $FutureProviderElement<List<Employee>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Employee>> create(Ref ref) {
    return allEmployees(ref);
  }
}

String _$allEmployeesHash() => r'803e328705a65f0a955573d0702b469c4cb14d47';

/// Reactive list of employees, filtered by [EmployeeSearch].

@ProviderFor(EmployeesList)
final employeesListProvider = EmployeesListProvider._();

/// Reactive list of employees, filtered by [EmployeeSearch].
final class EmployeesListProvider
    extends $AsyncNotifierProvider<EmployeesList, List<Employee>> {
  /// Reactive list of employees, filtered by [EmployeeSearch].
  EmployeesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'employeesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$employeesListHash();

  @$internal
  @override
  EmployeesList create() => EmployeesList();
}

String _$employeesListHash() => r'a2625048179c700cedf880e474389f6f4bc270fc';

/// Reactive list of employees, filtered by [EmployeeSearch].

abstract class _$EmployeesList extends $AsyncNotifier<List<Employee>> {
  FutureOr<List<Employee>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Employee>>, List<Employee>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Employee>>, List<Employee>>,
              AsyncValue<List<Employee>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
