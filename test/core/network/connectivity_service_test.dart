import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/config/app_config.dart';
import 'package:hasad_erp/core/network/connectivity_service.dart';

/// Records the URLs it was asked to probe and replays a scripted outcome.
class _FakeProbe {
  _FakeProbe(this.outcomes);

  /// One entry per call: `true` = reachable, `false` = unreachable,
  /// `null` = the probe throws (what a browser does on a CORS failure).
  final List<bool?> outcomes;
  final probedUrls = <Uri>[];

  int _calls = 0;

  Future<bool> call(Uri url, Duration timeout) async {
    probedUrls.add(url);
    final outcome = outcomes[_calls.clamp(0, outcomes.length - 1)];
    _calls++;
    if (outcome == null) throw const FormatException('probe blocked');
    return outcome;
  }
}

ConnectivityService _service(_FakeProbe probe) =>
    ConnectivityService(Connectivity(), probe: probe.call);

void main() {
  group('probe target', () {
    test('probes the app backend health endpoint, never a third party', () async {
      // Regression guard: the original probe hit
      // https://www.google.com/generate_204, which returns 204 with NO
      // Access-Control-Allow-Origin. A browser blocks that cross-origin
      // response, so package:http always threw and the app reported a false
      // "offline" even while fully connected.
      final probe = _FakeProbe([true]);
      await _service(probe).verifyInternetConnectivity();

      expect(probe.probedUrls, hasLength(1));
      final url = probe.probedUrls.single;
      expect(url, AppConfig.supabaseHealthUri);
      expect(url.host, Uri.parse(AppConfig.supabaseUrl).host);
      expect(url.path, '/auth/v1/health');
      expect(url.host, isNot(contains('google')));
    });
  });

  group('two-strike offline debounce', () {
    test('starts optimistic before any probe has run', () {
      final service = _service(_FakeProbe([false]));
      expect(service.isVerifiedOnline, isTrue);
    });

    test('a successful probe is online', () async {
      final service = _service(_FakeProbe([true]));
      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(service.isVerifiedOnline, isTrue);
    });

    test('one failure after being online stays online (no false banner)', () async {
      final service = _service(_FakeProbe([true, false]));

      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(await service.verifyInternetConnectivity(), isTrue,
          reason: 'a single blip must not flip a working connection offline');
      expect(service.isVerifiedOnline, isTrue);
    });

    test('two consecutive failures go offline', () async {
      final service = _service(_FakeProbe([true, false, false]));

      await service.verifyInternetConnectivity();
      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(await service.verifyInternetConnectivity(), isFalse);
      expect(service.isVerifiedOnline, isFalse);
    });

    test('recovery back online is instant, without needing a second success',
        () async {
      final service = _service(_FakeProbe([false, false, true]));

      await service.verifyInternetConnectivity();
      expect(await service.verifyInternetConnectivity(), isFalse);

      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(service.isVerifiedOnline, isTrue);
    });

    test('the failure counter resets after a success, so blips never stack',
        () async {
      // fail, success, fail -> still online: the middle success reset the count
      final service = _service(_FakeProbe([false, true, false]));

      await service.verifyInternetConnectivity();
      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(await service.verifyInternetConnectivity(), isTrue);
      expect(service.isVerifiedOnline, isTrue);
    });

    test('a throwing probe counts as a failure instead of crashing', () async {
      // A CORS-blocked response surfaces as a thrown error, not a status code.
      final service = _service(_FakeProbe([null, null]));

      await service.verifyInternetConnectivity();
      expect(await service.verifyInternetConnectivity(), isFalse);
      expect(service.isVerifiedOnline, isFalse);
    });

    test('a persistent failure stays offline across many probes', () async {
      final service = _service(_FakeProbe([false]));

      for (var i = 0; i < 5; i++) {
        await service.verifyInternetConnectivity();
      }
      expect(service.isVerifiedOnline, isFalse);
    });
  });
}
