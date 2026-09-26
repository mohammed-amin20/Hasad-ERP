import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'web_online.dart';

/// Probes whether [url] is reachable. Returns true on any 2xx.
typedef ConnectivityProbe = Future<bool> Function(Uri url, Duration timeout);

/// Default probe: the app's own backend health endpoint.
///
/// The `apikey` header is required (the endpoint answers 401 without it) and
/// is not CORS-safelisted, so the browser sends a preflight first — GoTrue
/// allows it and reflects the caller's origin on the 200, so `package:http`
/// (a `BrowserClient` on web) can actually read the response.
Future<bool> defaultConnectivityProbe(Uri url, Duration timeout) async {
  const headers = <String, String>{'apikey': AppConfig.supabaseAnonKey};
  if (kIsWeb) {
    final response = await http.get(url, headers: headers).timeout(timeout);
    return response.statusCode >= 200 && response.statusCode < 300;
  }
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(url);
    headers.forEach(request.headers.set);
    final response = await request.close();
    return response.statusCode >= 200 && response.statusCode < 300;
  } finally {
    client.close(force: true);
  }
}

class ConnectivityService {
  ConnectivityService(this._connectivity, {ConnectivityProbe? probe})
    : _probe = probe ?? defaultConnectivityProbe;

  final Connectivity _connectivity;
  final ConnectivityProbe _probe;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  List<ConnectivityResult> _lastResult = <ConnectivityResult>[
    ConnectivityResult.none,
  ];

  /// Consecutive failed probes. A single blip must not flip a working
  /// connection to "offline", so [_failureThreshold] failures in a row are
  /// required before the verdict goes negative.
  int _consecutiveFailures = 0;

  /// Starts optimistic: until a probe actually proves otherwise we assume the
  /// connection works, matching `isOnlineProvider`'s `?? true` default.
  bool _verifiedOnline = true;
  Timer? _verificationTimer;
  static const _verificationInterval = Duration(seconds: 30);
  static const _verificationTimeout = Duration(seconds: 5);
  static const int _failureThreshold = 2;

  Uri get _verificationUrl => AppConfig.supabaseHealthUri;

  Future<void> initialize() async {
    _lastResult = await _connectivity.checkConnectivity();
    _controller.add(_lastResult);

    _connectivity.onConnectivityChanged.listen((result) {
      if (!_listEquals(result, _lastResult)) {
        _lastResult = result;
        _controller.add(result);
        // Trigger verification when we have a network interface
        if (result.any((r) => r != ConnectivityResult.none)) {
          unawaited(verifyInternetConnectivity());
        } else {
          _recordProbeResult(false);
        }
      }
    });

    // Initial verification if we have an interface
    if (_lastResult.any((r) => r != ConnectivityResult.none)) {
      unawaited(verifyInternetConnectivity());
    }

    // Start periodic verification
    _startPeriodicVerification();
  }

  void _startPeriodicVerification() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(_verificationInterval, (_) {
      // No `!= none` gate: a persistent-offline state must still be re-probed
      // so the verdict can self-heal. On native the probe fails fast when
      // truly offline; on web the navigator.onLine fast-path makes it instant.
      unawaited(verifyInternetConnectivity());
    });
  }

  Future<bool> verifyInternetConnectivity() async {
    var reachable = false;
    try {
      if (kIsWeb) {
        // The browser's `navigator.onLine` is the authoritative, instant
        // offline signal on web (no HTTP wait). When it reports offline the
        // verdict can flip without waiting on a request that cannot succeed.
        if (!webNavigatorOnLine()) {
          return _recordProbeResult(false);
        }
      }
      // `dart:io` HttpClient is unavailable at runtime on Flutter web, and
      // the browser's connectivity events only reflect network interfaces.
      // Verify real internet access by probing the backend we depend on.
      reachable = await _probe(_verificationUrl, _verificationTimeout);
    } catch (_) {
      reachable = false;
    }
    return _recordProbeResult(reachable);
  }

  /// Folds one probe outcome into the debounced verdict. Recovery is instant;
  /// going offline needs [_failureThreshold] consecutive failures.
  bool _recordProbeResult(bool reachable) {
    if (reachable) {
      _consecutiveFailures = 0;
      _verifiedOnline = true;
    } else {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _failureThreshold) {
        _verifiedOnline = false;
      }
    }
    return _verifiedOnline;
  }

  Future<List<ConnectivityResult>> checkConnectivity() async {
    _lastResult = await _connectivity.checkConnectivity();
    return _lastResult;
  }
  bool get isVerifiedOnline => _verifiedOnline;
  bool get hasInterface => _lastResult.any((r) => r != ConnectivityResult.none);

  ConnectivityResult get primaryResult =>
      _lastResult.isNotEmpty ? _lastResult.first : ConnectivityResult.none;
  List<ConnectivityResult> get lastResult => List.unmodifiable(_lastResult);

  void dispose() {
    _verificationTimer?.cancel();
    _controller.close();
  }

  bool _listEquals(List<ConnectivityResult> a, List<ConnectivityResult> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
extension ConnectivityResultX on ConnectivityResult {
  String get arabicLabel {
    switch (this) {
      case ConnectivityResult.wifi:
        return 'واي فاي';
      case ConnectivityResult.mobile:
        return 'بيانات متنقلة';
      case ConnectivityResult.ethernet:
        return 'إيثرنت';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'بلوتوث';
      case ConnectivityResult.other:
        return 'أخرى';
      case ConnectivityResult.none:
      default:
        return 'غير متصل';
    }
  }

  bool get hasInternet => this != ConnectivityResult.none;
}
