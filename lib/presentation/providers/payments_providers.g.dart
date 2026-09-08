// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paymentRepository)
final paymentRepositoryProvider = PaymentRepositoryProvider._();

final class PaymentRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentRepository,
          PaymentRepository,
          PaymentRepository
        >
    with $Provider<PaymentRepository> {
  PaymentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentRepository create(Ref ref) {
    return paymentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentRepository>(value),
    );
  }
}

String _$paymentRepositoryHash() => r'd0ba21eedfe7995ad50a23fbdb97d24b839ed3cc';

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.

@ProviderFor(PaymentActions)
final paymentActionsProvider = PaymentActionsProvider._();

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.
final class PaymentActionsProvider
    extends $NotifierProvider<PaymentActions, Object?> {
  /// Executes payment actions and then refreshes both invoice lists so the
  /// new status/remaining reach the UI immediately.
  PaymentActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentActionsHash();

  @$internal
  @override
  PaymentActions create() => PaymentActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Object? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Object?>(value),
    );
  }
}

String _$paymentActionsHash() => r'ece9878b49422cc4305ba28a89274ad41a3ed201';

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.

abstract class _$PaymentActions extends $Notifier<Object?> {
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
