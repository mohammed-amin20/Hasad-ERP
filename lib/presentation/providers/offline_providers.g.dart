// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves the current tenant id (null until the session load settles).

@ProviderFor(currentTenantId)
final currentTenantIdProvider = CurrentTenantIdProvider._();

/// Resolves the current tenant id (null until the session load settles).

final class CurrentTenantIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Resolves the current tenant id (null until the session load settles).
  CurrentTenantIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTenantIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTenantIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentTenantId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentTenantIdHash() => r'ae7eaab368a9a91622d0474e5037274790e9f657';

/// Resolves the opened local store (null on web or while opening).

@ProviderFor(localStoreBox)
final localStoreBoxProvider = LocalStoreBoxProvider._();

/// Resolves the opened local store (null on web or while opening).

final class LocalStoreBoxProvider
    extends $FunctionalProvider<LocalStore?, LocalStore?, LocalStore?>
    with $Provider<LocalStore?> {
  /// Resolves the opened local store (null on web or while opening).
  LocalStoreBoxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStoreBoxProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStoreBoxHash();

  @$internal
  @override
  $ProviderElement<LocalStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalStore? create(Ref ref) {
    return localStoreBox(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStore?>(value),
    );
  }
}

String _$localStoreBoxHash() => r'4d2b0de0665156093bf54accf332b40266985b2f';

/// Last-succesful-fetch time of the cached report under [key], or null when
/// it was never cached (drives the freshness indicator).

@ProviderFor(reportCachedAt)
final reportCachedAtProvider = ReportCachedAtFamily._();

/// Last-succesful-fetch time of the cached report under [key], or null when
/// it was never cached (drives the freshness indicator).

final class ReportCachedAtProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// Last-succesful-fetch time of the cached report under [key], or null when
  /// it was never cached (drives the freshness indicator).
  ReportCachedAtProvider._({
    required ReportCachedAtFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reportCachedAtProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reportCachedAtHash();

  @override
  String toString() {
    return r'reportCachedAtProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    final argument = this.argument as String;
    return reportCachedAt(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportCachedAtProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reportCachedAtHash() => r'a8ed38bc949da3d1028c9b77104b982e5fc00fcb';

/// Last-succesful-fetch time of the cached report under [key], or null when
/// it was never cached (drives the freshness indicator).

final class ReportCachedAtFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DateTime?>, String> {
  ReportCachedAtFamily._()
    : super(
        retry: null,
        name: r'reportCachedAtProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Last-succesful-fetch time of the cached report under [key], or null when
  /// it was never cached (drives the freshness indicator).

  ReportCachedAtProvider call(String key) =>
      ReportCachedAtProvider._(argument: key, from: this);

  @override
  String toString() => r'reportCachedAtProvider';
}
