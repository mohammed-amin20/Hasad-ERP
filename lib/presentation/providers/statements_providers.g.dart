// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statements_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(statementRepository)
final statementRepositoryProvider = StatementRepositoryProvider._();

final class StatementRepositoryProvider
    extends
        $FunctionalProvider<
          StatementRepository,
          StatementRepository,
          StatementRepository
        >
    with $Provider<StatementRepository> {
  StatementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statementRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statementRepositoryHash();

  @$internal
  @override
  $ProviderElement<StatementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatementRepository create(Ref ref) {
    return statementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatementRepository>(value),
    );
  }
}

String _$statementRepositoryHash() =>
    r'1a714986d5b7d9a70b0a566e7241ac9cac42fcd9';

@ProviderFor(debtsRepository)
final debtsRepositoryProvider = DebtsRepositoryProvider._();

final class DebtsRepositoryProvider
    extends
        $FunctionalProvider<DebtsRepository, DebtsRepository, DebtsRepository>
    with $Provider<DebtsRepository> {
  DebtsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debtsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debtsRepositoryHash();

  @$internal
  @override
  $ProviderElement<DebtsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DebtsRepository create(Ref ref) {
    return debtsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DebtsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DebtsRepository>(value),
    );
  }
}

String _$debtsRepositoryHash() => r'a5e5067152cd04ebb26f6688ff3eb01828cfc509';

/// Customer outstanding balances (what customers owe us).

@ProviderFor(customerDebts)
final customerDebtsProvider = CustomerDebtsProvider._();

/// Customer outstanding balances (what customers owe us).

final class CustomerDebtsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PartyBalance>>,
          List<PartyBalance>,
          FutureOr<List<PartyBalance>>
        >
    with
        $FutureModifier<List<PartyBalance>>,
        $FutureProvider<List<PartyBalance>> {
  /// Customer outstanding balances (what customers owe us).
  CustomerDebtsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerDebtsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerDebtsHash();

  @$internal
  @override
  $FutureProviderElement<List<PartyBalance>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PartyBalance>> create(Ref ref) {
    return customerDebts(ref);
  }
}

String _$customerDebtsHash() => r'275d04abeec0859c88c6b07a649b241a795ca800';

/// Supplier outstanding balances (what we owe suppliers: owned invoices +
/// commission dues).

@ProviderFor(supplierDebts)
final supplierDebtsProvider = SupplierDebtsProvider._();

/// Supplier outstanding balances (what we owe suppliers: owned invoices +
/// commission dues).

final class SupplierDebtsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PartyBalance>>,
          List<PartyBalance>,
          FutureOr<List<PartyBalance>>
        >
    with
        $FutureModifier<List<PartyBalance>>,
        $FutureProvider<List<PartyBalance>> {
  /// Supplier outstanding balances (what we owe suppliers: owned invoices +
  /// commission dues).
  SupplierDebtsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierDebtsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierDebtsHash();

  @$internal
  @override
  $FutureProviderElement<List<PartyBalance>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PartyBalance>> create(Ref ref) {
    return supplierDebts(ref);
  }
}

String _$supplierDebtsHash() => r'8466b116155fb45d901bc423f90d63200c794d42';

/// A single party's statement, keyed by (type, id, from, to).

@ProviderFor(partyStatement)
final partyStatementProvider = PartyStatementFamily._();

/// A single party's statement, keyed by (type, id, from, to).

final class PartyStatementProvider
    extends
        $FunctionalProvider<
          AsyncValue<PartyStatement>,
          PartyStatement,
          FutureOr<PartyStatement>
        >
    with $FutureModifier<PartyStatement>, $FutureProvider<PartyStatement> {
  /// A single party's statement, keyed by (type, id, from, to).
  PartyStatementProvider._({
    required PartyStatementFamily super.from,
    required StatementRequest super.argument,
  }) : super(
         retry: null,
         name: r'partyStatementProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$partyStatementHash();

  @override
  String toString() {
    return r'partyStatementProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PartyStatement> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PartyStatement> create(Ref ref) {
    final argument = this.argument as StatementRequest;
    return partyStatement(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PartyStatementProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$partyStatementHash() => r'66dd6d10f46b4081cd23ea1fcf5a8495877ad7b0';

/// A single party's statement, keyed by (type, id, from, to).

final class PartyStatementFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PartyStatement>, StatementRequest> {
  PartyStatementFamily._()
    : super(
        retry: null,
        name: r'partyStatementProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A single party's statement, keyed by (type, id, from, to).

  PartyStatementProvider call(StatementRequest request) =>
      PartyStatementProvider._(argument: request, from: this);

  @override
  String toString() => r'partyStatementProvider';
}
