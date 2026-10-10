import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/amnezia/agw_ffi.dart';

const _testKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv76aYFAVnthF7pFO8bW/
Sbo0Wls5sDvapOmyz9j74sL+nqqsAiMbfqIi8A4m9y94jsCA9t+AoTg0IwjKZMpd
3zO0G6Npb2p2uS/XK+gBeKp/cd3N/Q8KkZgCvY1RDHC7dGgVAzGOwx0OVdkHQA9I
536B2btJk8BhBbQQGNFWs9+w5kHrflMMyYByxTpKktY0EAIl8Yh9qQcbtv/zVg8Y
0wfaVtqwlYNRtvAQK+R475y+Nw6QdcSW63QrKytrvBSov7HXeHhrKT6zJysDKgc+
htyMd4Vz9KdlPjg/9bJ4dnnggoIgc72oQxpJvF0sgUXJmTYvVR5mgU5CsEt8jeJW
MQIDAQAB
-----END PUBLIC KEY-----
''';

final _needsLibrary = Platform.environment.containsKey('AGW_LIBRARY')
    ? null
    : 'needs a host build of libagw in AGW_LIBRARY';

void main() {
  AgwClient clientFor(HttpServer gateway) => AgwClient(
    AgwConfig(
      endpoint: 'http://127.0.0.1:${gateway.port}/',
      publicKeyPem: _testKey,
    ),
  );

  test(
    'calls take turns, so a later one starts from what the first learned',
    () async {
      var inFlight = 0;
      var most = 0;
      final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      gateway.listen((req) async {
        inFlight++;
        if (inFlight > most) most = inFlight;
        await req.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        req.response.write('<html>blocked</html>');
        await req.response.close();
        inFlight--;
      });
      addTearDown(gateway.close);
      final client = clientFor(gateway);

      await Future.wait([
        client.post('v1/account_info', {}),
        client.post('v1/config', {}),
      ]);

      expect(most, 1);
    },
    skip: _needsLibrary,
  );

  test(
    'a cancelled connect stops the sweep and the calls queued behind it',
    () async {
      final gateway = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      gateway.listen((req) => req.drain<void>());
      addTearDown(() => gateway.close(force: true));
      final client = clientFor(gateway);

      final started = Stopwatch()..start();
      final first = client.post('v1/account_info', {});
      final queued = client.post('v1/config', {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      client.cancelAll();

      expect((await first).code, AgwStatus.cancelled);
      expect((await queued).code, AgwStatus.cancelled);
      expect(started.elapsed, lessThan(const Duration(seconds: 5)));
    },
    skip: _needsLibrary,
  );
}
