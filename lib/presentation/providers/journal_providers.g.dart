// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Journal repository wired to Supabase.

@ProviderFor(journalRepository)
final journalRepositoryProvider = JournalRepositoryProvider._();

/// Journal repository wired to Supabase.

final class JournalRepositoryProvider
    extends
        $FunctionalProvider<
          JournalRepository,
          JournalRepository,
          JournalRepository
        >
    with $Provider<JournalRepository> {
  /// Journal repository wired to Supabase.
  JournalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalRepositoryHash();

  @$internal
  @override
  $ProviderElement<JournalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  JournalRepository create(Ref ref) {
    return journalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalRepository>(value),
    );
  }
}

String _$journalRepositoryHash() => r'c73cb21d441c6bb96798d539617adfe4cd033391';

/// Current journal date range (first day of the month → today by default).

@ProviderFor(JournalRange)
final journalRangeProvider = JournalRangeProvider._();

/// Current journal date range (first day of the month → today by default).
final class JournalRangeProvider
    extends $NotifierProvider<JournalRange, ({DateTime from, DateTime to})> {
  /// Current journal date range (first day of the month → today by default).
  JournalRangeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalRangeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalRangeHash();

  @$internal
  @override
  JournalRange create() => JournalRange();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({DateTime from, DateTime to}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({DateTime from, DateTime to})>(
        value,
      ),
    );
  }
}

String _$journalRangeHash() => r'f0e40da849ccf4e8a70c1ccb4ba11a404ae4c1f0';

/// Current journal date range (first day of the month → today by default).

abstract class _$JournalRange
    extends $Notifier<({DateTime from, DateTime to})> {
  ({DateTime from, DateTime to}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({DateTime from, DateTime to}),
              ({DateTime from, DateTime to})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({DateTime from, DateTime to}),
                ({DateTime from, DateTime to})
              >,
              ({DateTime from, DateTime to}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Journal entries in the selected range, newest first.

@ProviderFor(JournalList)
final journalListProvider = JournalListProvider._();

/// Journal entries in the selected range, newest first.
final class JournalListProvider
    extends $AsyncNotifierProvider<JournalList, List<JournalEntry>> {
  /// Journal entries in the selected range, newest first.
  JournalListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalListHash();

  @$internal
  @override
  JournalList create() => JournalList();
}

String _$journalListHash() => r'080704ca45ad9c0c0ec295cd7a95d05d15f87481';

/// Journal entries in the selected range, newest first.

abstract class _$JournalList extends $AsyncNotifier<List<JournalEntry>> {
  FutureOr<List<JournalEntry>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalEntry>>, List<JournalEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<JournalEntry>>, List<JournalEntry>>,
              AsyncValue<List<JournalEntry>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
