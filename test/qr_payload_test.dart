import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/parsers/qr_payload.dart';
import 'package:anoya/core/parsers/subscription.dart';

void main() {
  String noise(int seed) {
    final r = Random(seed);
    return String.fromCharCodes(
      List.generate(2400, (_) => 0x21 + r.nextInt(90)),
    );
  }

  String premiumKey({String name = 'Amnezia Premium'}) {
    final doc = {
      'name': name,
      'config_version': 2,
      'api_config': {
        'service_type': 'amnezia-premium',
        'service_protocol': 'awg',
        'user_country_code': 'ru',
      },
      'auth_data': {'api_key': 'a-subscription-key'},
    };
    final body = ZLibCodec().encode(utf8.encode(jsonEncode(doc)));
    final b64 = base64Url
        .encode(Uint8List.fromList([0, 0, 0, 0xff, ...body]))
        .replaceAll('=', '');
    return 'vpn://$b64';
  }

  List<String> amneziaQrSeries(String key) {
    final data = utf8.encode(key.replaceFirst('vpn://', ''));
    const k = 850;
    final count = (data.length / k).ceil();
    return [
      for (var i = 0; i * k < data.length; i++)
        () {
          final chunk = data.sublist(i * k, (i * k + k).clamp(0, data.length));
          final head = ByteData(8)
            ..setInt16(0, kAmneziaQrMagic)
            ..setUint8(2, count)
            ..setUint8(3, i)
            ..setUint32(4, chunk.length);
          return base64Url
              .encode([...head.buffer.asUint8List(), ...chunk])
              .replaceAll('=', '');
        }(),
    ];
  }

  group('an Amnezia key shown as QR codes', () {
    test('a short key is one part, and still wrapped', () {
      final key = premiumKey();
      final series = amneziaQrSeries(key);
      expect(series, hasLength(1));

      final step = QrReader().read(series.single);

      expect(step, isA<QrText>());
      final text = (step as QrText).text;
      expect(
        text,
        key,
        reason: 'the vpn:// prefix the app stripped comes back',
      );
      expect(detectInput(text)?.kind, InputKind.amneziaKey);
    });

    test('parts come in any order, repeats included, and count up', () {
      final key = premiumKey(name: noise(1));
      final series = amneziaQrSeries(key);
      expect(series.length, greaterThan(2));
      final reader = QrReader();

      final last = series.length - 1;
      final first = reader.read(series[last]);
      expect(first, isA<QrParts>());
      expect((first as QrParts).received, 1);
      expect(first.total, series.length);

      final again = reader.read(series[last]) as QrParts;
      expect(again.received, 1, reason: 'the app cycles the same parts');

      QrStep step = again;
      for (var i = 0; i < last; i++) {
        step = reader.read(series[i]);
      }
      expect((step as QrText).text, key);
    });

    test('a different key midway starts the count over', () {
      final long = amneziaQrSeries(premiumKey(name: noise(2)));
      final short = amneziaQrSeries(premiumKey());
      final reader = QrReader();

      reader.read(long[0]);
      final step = reader.read(short.single);

      expect((step as QrText).text, premiumKey());
    });
  });

  group('what panels and providers put in a QR code', () {
    test('a server link is the link', () {
      const link = 'vless://uuid@1.2.3.4:443?type=tcp#Tokyo';
      expect((QrReader().read(link) as QrText).text, link);
    });

    test('a subscription address is the address', () {
      const url = 'https://panel.example/sub/abc123';
      expect((QrReader().read('  $url\n') as QrText).text, url);
    });

    test('client deep links give up the address inside', () {
      const url = 'https://panel.example/sub/abc123';
      for (final wrapped in [
        'happ://add/$url',
        'v2raytun://import/$url',
        'hiddify://import/$url',
        'streisand://import/$url',
        'sing-box://import-remote-profile?url=${Uri.encodeComponent(url)}#Work',
        'clash://install-config?url=${Uri.encodeComponent(url)}',
        'v2rayng://install-config?url=${Uri.encodeComponent(url)}',
      ]) {
        expect(unwrapImportLink(wrapped), url, reason: wrapped);
      }
    });

    test('a link we read ourselves is never unwrapped', () {
      const link =
          'vless://uuid@1.2.3.4:443?url=https://evil.example/x&type=tcp#a';
      expect(unwrapImportLink(link), link);
    });

    test('a wrapper with nothing usable inside is left as it came', () {
      expect(unwrapImportLink('happ://crypt/AbCdEf'), 'happ://crypt/AbCdEf');
      expect(unwrapImportLink('foo://x?url=%zz'), 'foo://x?url=%zz');
    });

    test('plain words that happen to be base64 are not an Amnezia part', () {
      expect(
        (QrReader().read('HelloWorldThisIsText') as QrText).text,
        'HelloWorldThisIsText',
      );
    });
  });
}
