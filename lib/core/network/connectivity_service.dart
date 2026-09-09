import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service that monitors network connectivity changes.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  List<ConnectivityResult> _lastResult = <ConnectivityResult>[ConnectivityResult.none];

  Future<void> initialize() async {
    _lastResult = await _connectivity.checkConnectivity();
    _controller.add(_lastResult);

    _connectivity.onConnectivityChanged.listen((result) {
      if (!_listEquals(result, _lastResult)) {
        _lastResult = result;
        _controller.add(result);
      }
    });
  }

  Future<List<ConnectivityResult>> checkConnectivity() async {
    _lastResult = await _connectivity.checkConnectivity();
    return _lastResult;
  }

  bool get isConnected => _lastResult.any((r) => r != ConnectivityResult.none);

  ConnectivityResult get primaryResult => _lastResult.isNotEmpty ? _lastResult.first : ConnectivityResult.none;

  /// Current connectivity results (for external access)
  List<ConnectivityResult> get lastResult => List.unmodifiable(_lastResult);

  void dispose() {
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