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

String _$paymentRepositoryHash() => r'5fe99eea3f2ace18c8dff39e309f0fdfa61f2ecd';

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The sheets reach
/// this notifier with `ref.read(paymentActionsProvider.notifier)` and then hold
/// it across `await record(...)`, so the notifier's own `ref` is used again in
/// `_refresh()` *after* the await. An auto-dispose provider that nothing
/// `watch`es is disposed at the end of the first frame that follows the read,
/// and the post-await `ref.invalidate` then throws
/// `UnmountedRefException: Cannot use the Ref of paymentActionsProvider after
/// it has been disposed` — which the sheet's own `catch` renders as the generic
/// `حدث خطأ غير متوقع` banner while the write itself has already landed. The user
/// retries, and the second attempt is the one that double-pays.
///
/// The signature of this defect is that it is **invisible to a state
/// assertion**: the banner is the only observable, and `tester.takeException()`
/// is null either way. Proven both ways in `offline_payment_sheet_test.dart` and
/// `offline_settlement_sheet_test.dart` — reverting this annotation fails all
/// three cases. It holds no state (`build() => null`), so nothing leaks.
///
/// Any other provider whose notifier is only ever `read` from a sheet and used
/// across an `await` has the same defect — see `SalaryActions`.

@ProviderFor(PaymentActions)
final paymentActionsProvider = PaymentActionsProvider._();

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The sheets reach
/// this notifier with `ref.read(paymentActionsProvider.notifier)` and then hold
/// it across `await record(...)`, so the notifier's own `ref` is used again in
/// `_refresh()` *after* the await. An auto-dispose provider that nothing
/// `watch`es is disposed at the end of the first frame that follows the read,
/// and the post-await `ref.invalidate` then throws
/// `UnmountedRefException: Cannot use the Ref of paymentActionsProvider after
/// it has been disposed` — which the sheet's own `catch` renders as the generic
/// `حدث خطأ غير متوقع` banner while the write itself has already landed. The user
/// retries, and the second attempt is the one that double-pays.
///
/// The signature of this defect is that it is **invisible to a state
/// assertion**: the banner is the only observable, and `tester.takeException()`
/// is null either way. Proven both ways in `offline_payment_sheet_test.dart` and
/// `offline_settlement_sheet_test.dart` — reverting this annotation fails all
/// three cases. It holds no state (`build() => null`), so nothing leaks.
///
/// Any other provider whose notifier is only ever `read` from a sheet and used
/// across an `await` has the same defect — see `SalaryActions`.
final class PaymentActionsProvider
    extends $NotifierProvider<PaymentActions, Object?> {
  /// Executes payment actions and then refreshes both invoice lists so the
  /// new status/remaining reach the UI immediately.
  ///
  /// **`keepAlive: true` is load-bearing, not an optimisation.** The sheets reach
  /// this notifier with `ref.read(paymentActionsProvider.notifier)` and then hold
  /// it across `await record(...)`, so the notifier's own `ref` is used again in
  /// `_refresh()` *after* the await. An auto-dispose provider that nothing
  /// `watch`es is disposed at the end of the first frame that follows the read,
  /// and the post-await `ref.invalidate` then throws
  /// `UnmountedRefException: Cannot use the Ref of paymentActionsProvider after
  /// it has been disposed` — which the sheet's own `catch` renders as the generic
  /// `حدث خطأ غير متوقع` banner while the write itself has already landed. The user
  /// retries, and the second attempt is the one that double-pays.
  ///
  /// The signature of this defect is that it is **invisible to a state
  /// assertion**: the banner is the only observable, and `tester.takeException()`
  /// is null either way. Proven both ways in `offline_payment_sheet_test.dart` and
  /// `offline_settlement_sheet_test.dart` — reverting this annotation fails all
  /// three cases. It holds no state (`build() => null`), so nothing leaks.
  ///
  /// Any other provider whose notifier is only ever `read` from a sheet and used
  /// across an `await` has the same defect — see `SalaryActions`.
  PaymentActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentActionsProvider',
        isAutoDispose: false,
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

String _$paymentActionsHash() => r'b875ba87769e9e55591313282d27b273da9148b3';

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The sheets reach
/// this notifier with `ref.read(paymentActionsProvider.notifier)` and then hold
/// it across `await record(...)`, so the notifier's own `ref` is used again in
/// `_refresh()` *after* the await. An auto-dispose provider that nothing
/// `watch`es is disposed at the end of the first frame that follows the read,
/// and the post-await `ref.invalidate` then throws
/// `UnmountedRefException: Cannot use the Ref of paymentActionsProvider after
/// it has been disposed` — which the sheet's own `catch` renders as the generic
/// `حدث خطأ غير متوقع` banner while the write itself has already landed. The user
/// retries, and the second attempt is the one that double-pays.
///
/// The signature of this defect is that it is **invisible to a state
/// assertion**: the banner is the only observable, and `tester.takeException()`
/// is null either way. Proven both ways in `offline_payment_sheet_test.dart` and
/// `offline_settlement_sheet_test.dart` — reverting this annotation fails all
/// three cases. It holds no state (`build() => null`), so nothing leaks.
///
/// Any other provider whose notifier is only ever `read` from a sheet and used
/// across an `await` has the same defect — see `SalaryActions`.

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
