import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

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
      if (_lastResult.any((r) => r != ConnectivityResult.none)) {
        unawaited(verifyInternetConnectivity());
      }
    });
  }

  Future<bool> verifyInternetConnectivity() async {
    try {
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
