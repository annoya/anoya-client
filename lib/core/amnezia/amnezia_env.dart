import 'dart:convert';

import '../app_version.dart';

class AmneziaEnv {
  const AmneziaEnv._();

  static const endpoint = String.fromEnvironment(
    'AGW_ENDPOINT',
    defaultValue: 'http://gw.amnezia.org:80/',
  );

  // Base64, not raw PEM: Gradle mangles newlines in --dart-define, and the exact
  // bytes are the SHA-512 key to the bypass proxy lists.
  static const _publicKeyB64 = String.fromEnvironment('AGW_PUBLIC_KEY_B64');

  static String get publicKeyPem {
    if (_publicKeyB64.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(_publicKeyB64));
    } on FormatException {
      return '';
    }
  }

  static const _s3 = String.fromEnvironment('AGW_S3_ENDPOINTS');

  static const _s3Fallback = String.fromEnvironment(
    'AGW_S3_FALLBACK_ENDPOINTS',
  );

  static List<String> get s3Endpoints => _urls(_s3);

  static List<String> get s3FallbackEndpoints => _urls(_s3Fallback);

  static List<String> _urls(String csv) => csv
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static const clientName = 'AnnoyaTest';
  static String get clientVersion => appVersion;
  static const distribution = '';
}
