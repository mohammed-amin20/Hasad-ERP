// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reminder repository wired to Supabase.

@ProviderFor(reminderRepository)
final reminderRepositoryProvider = ReminderRepositoryProvider._();

/// Reminder repository wired to Supabase.

final class ReminderRepositoryProvider
    extends
        $FunctionalProvider<
          ReminderRepository,
          ReminderRepository,
          ReminderRepository
        >
    with $Provider<ReminderRepository> {
  /// Reminder repository wired to Supabase.
  ReminderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReminderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReminderRepository create(Ref ref) {
    return reminderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderRepository>(value),
    );
  }
}

String _$reminderRepositoryHash() =>
    r'f4630ac40bc335125124e33b11d8d8aada233258';

/// The current tenant's reminder settings (webhook, template, threshold).

@ProviderFor(ReminderSettingsController)
final reminderSettingsControllerProvider =
    ReminderSettingsControllerProvider._();

/// The current tenant's reminder settings (webhook, template, threshold).
final class ReminderSettingsControllerProvider
    extends
        $AsyncNotifierProvider<ReminderSettingsController, ReminderSettings> {
  /// The current tenant's reminder settings (webhook, template, threshold).
  ReminderSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSettingsControllerHash();

  @$internal
  @override
  ReminderSettingsController create() => ReminderSettingsController();
}

String _$reminderSettingsControllerHash() =>
    r'bceb4340e7fa8ce50824ec226a543215b87d85ea';

/// The current tenant's reminder settings (webhook, template, threshold).

abstract class _$ReminderSettingsController
    extends $AsyncNotifier<ReminderSettings> {
  FutureOr<ReminderSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReminderSettings>, ReminderSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReminderSettings>, ReminderSettings>,
              AsyncValue<ReminderSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Most recent reminder sends, newest first.

@ProviderFor(ReminderLog)
final reminderLogProvider = ReminderLogProvider._();

/// Most recent reminder sends, newest first.
final class ReminderLogProvider
    extends $AsyncNotifierProvider<ReminderLog, List<ReminderLogEntry>> {
  /// Most recent reminder sends, newest first.
  ReminderLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderLogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderLogHash();

  @$internal
  @override
  ReminderLog create() => ReminderLog();
}

String _$reminderLogHash() => r'4bbb7d62f3d740ecfe8127278aa3fe370bb228f9';

/// Most recent reminder sends, newest first.

abstract class _$ReminderLog extends $AsyncNotifier<List<ReminderLogEntry>> {
  FutureOr<List<ReminderLogEntry>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ReminderLogEntry>>, List<ReminderLogEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ReminderLogEntry>>,
                List<ReminderLogEntry>
              >,
              AsyncValue<List<ReminderLogEntry>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
