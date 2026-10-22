import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/amnezia/agw_ffi.dart';

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
        'request_timeout_msecs',
        'proxy_request_timeout_msecs',
        'proxy_storage_timeout_msecs',
        'proxy_health_timeout_msecs',
      ]) {
        expect(
          header,
          contains('"$key"'),
          reason: '$key is not what the library reads any more',
        );
      }
    },
  );

  test('every attempt gets its timeout: gateway, proxy, storage, health', () {
    final json = const AgwConfig(
      endpoint: 'https://gw.example.com/',
      publicKeyPem: 'x',
    ).toJson();
    expect(json['request_timeout_msecs'], 6000);
    expect(json['proxy_request_timeout_msecs'], 6000);
    expect(json['proxy_storage_timeout_msecs'], 6000);
    expect(json['proxy_health_timeout_msecs'], 1000);
  });

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
