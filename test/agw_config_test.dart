import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/amnezia/agw_ffi.dart';

/// The config the app hands *into* the gateway library.
///
/// The library parses this JSON and ignores what it does not recognise, so a
/// misspelled key is not an error — it is a feature that silently stops
/// working. The storage lists are exactly that kind of key: without them the
/// bypass path has nothing to resolve, and the only symptom is that the
/// gateway becomes unreachable wherever it is blocked. So the names are
/// checked against the C header that defines them.
void main() {
  test(
    'the storage lists reach the library under the names its ABI defines',
    () {
      const cfg = AgwConfig(
        endpoint: 'https://gw.example.com/',
        publicKeyPem:
            '-----BEGIN PUBLIC KEY-----\nx\n-----END PUBLIC KEY-----\n',
        s3Primary: ['https://p1.example.com/', 'https://p2.example.com/'],
        s3Fallback: ['https://f1.example.com/'],
      );

      final json = cfg.toJson();
      expect(json['s3_primary_endpoints'], [
        'https://p1.example.com/',
        'https://p2.example.com/',
      ]);
      expect(json['s3_fallback_endpoints'], ['https://f1.example.com/']);

      final header = File(
        'native/libagw/upstream/cabi/agw.h',
      ).readAsStringSync();
      for (final key in [
        'gateway_endpoint',
        'public_key_pem',
        's3_primary_endpoints',
        's3_fallback_endpoints',
      ]) {
        expect(
          header,
          contains('"$key"'),
          reason: '$key is not what the library reads any more',
        );
      }
    },
  );

  test('a list nobody supplied is left out, not sent empty', () {
    const cfg = AgwConfig(
      endpoint: 'https://gw.example.com/',
      publicKeyPem: 'x',
    );
    final json = cfg.toJson();
    expect(json.containsKey('s3_primary_endpoints'), isFalse);
    expect(json.containsKey('s3_fallback_endpoints'), isFalse);
  });
}
