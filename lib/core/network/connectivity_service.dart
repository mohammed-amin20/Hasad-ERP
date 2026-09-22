import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'web_online.dart';

/// Service that monitors network connectivity changes.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  List<ConnectivityResult> _lastResult = <ConnectivityResult>[
    ConnectivityResult.none,
  ];

  bool _verifiedOnline = false;
  Timer? _verificationTimer;
  static const _verificationInterval = Duration(seconds: 30);
  static const _verificationTimeout = Duration(seconds: 5);
  static const _verificationUrl = 'https://www.google.com/generate_204';

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
          _verifiedOnline = false;
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
    try {
      if (kIsWeb) {
        // The browser's `navigator.onLine` is the authoritative, instant
        // offline signal on web (no HTTP wait). When it reports offline the
        // verdict flips to `false` immediately; otherwise fall through to the
        // HTTP 204/200 probe which is authoritative for a browser that reports
        // an interface but has no real internet access.
        if (!webNavigatorOnLine()) {
          _verifiedOnline = false;
          return _verifiedOnline;
        }
        // `dart:io` HttpClient is unavailable at runtime on Flutter web, and
        // the browser's connectivity events only reflect network interfaces.
        // Verify real internet access via an HTTP 204/200 endpoint instead.
        final response = await http
            .get(Uri.parse(_verificationUrl))
            .timeout(_verificationTimeout);
        _verifiedOnline =
            response.statusCode == 204 || response.statusCode == 200;
        return _verifiedOnline;
      }
      final client = HttpClient();
      client.connectionTimeout = _verificationTimeout;
      final request = await client.getUrl(Uri.parse(_verificationUrl));
      final response = await request.close();
      _verifiedOnline = response.statusCode == 204 || response.statusCode == 200;
      client.close();
    } catch (_) {
      _verifiedOnline = false;
    }
    return _verifiedOnline;
  }

  Future<List<ConnectivityResult>> checkConnectivity() async {
    _lastResult = await _connectivity.checkConnectivity();
    return _lastResult;
  }

  /// True only if we have a network interface AND verified internet access
  bool get isVerifiedOnline => _verifiedOnline;

  /// True if any network interface is up (instant, may be false positive)
  bool get hasInterface => _lastResult.any((r) => r != ConnectivityResult.none);

  ConnectivityResult get primaryResult =>
      _lastResult.isNotEmpty ? _lastResult.first : ConnectivityResult.none;

  /// Current connectivity results (for external access)
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

/// Extension for user-friendly connectivity status
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
