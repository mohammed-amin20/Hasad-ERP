// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customers_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Concrete customer repository wired to Supabase.

@ProviderFor(customerRepository)
final customerRepositoryProvider = CustomerRepositoryProvider._();

/// Concrete customer repository wired to Supabase.

final class CustomerRepositoryProvider
    extends
        $FunctionalProvider<
          CustomerRepository,
          CustomerRepository,
          CustomerRepository
        >
    with $Provider<CustomerRepository> {
  /// Concrete customer repository wired to Supabase.
  CustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerRepositoryHash();

  @$internal
  @override
  $ProviderElement<CustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerRepository create(Ref ref) {
    return customerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerRepository>(value),
    );
  }
}

String _$customerRepositoryHash() =>
    r'b9a2bb94e5f42f0ac8b8b9ddb8fff08e6ecc9f0b';

/// Current search term for the customer list (reactive).

@ProviderFor(CustomerSearch)
final customerSearchProvider = CustomerSearchProvider._();

/// Current search term for the customer list (reactive).
final class CustomerSearchProvider
    extends $NotifierProvider<CustomerSearch, String> {
  /// Current search term for the customer list (reactive).
  CustomerSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerSearchHash();

  @$internal
  @override
  CustomerSearch create() => CustomerSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$customerSearchHash() => r'518c6d654176435545023d89db351f1b9a014ae0';

/// Current search term for the customer list (reactive).

abstract class _$CustomerSearch extends $Notifier<String> {
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

/// Reactive list of customers, filtered by [CustomerSearch].

@ProviderFor(CustomersList)
final customersListProvider = CustomersListProvider._();

/// Reactive list of customers, filtered by [CustomerSearch].
final class CustomersListProvider
    extends $AsyncNotifierProvider<CustomersList, List<Customer>> {
  /// Reactive list of customers, filtered by [CustomerSearch].
  CustomersListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customersListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customersListHash();

  @$internal
  @override
  CustomersList create() => CustomersList();
}

String _$customersListHash() => r'6ab0e24e3df91d7e9a1736607d8fc62004172db1';

/// Reactive list of customers, filtered by [CustomerSearch].

abstract class _$CustomersList extends $AsyncNotifier<List<Customer>> {
  FutureOr<List<Customer>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Customer>>, List<Customer>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Customer>>, List<Customer>>,
              AsyncValue<List<Customer>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
