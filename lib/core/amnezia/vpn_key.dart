import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../l10n/l10n.dart';

class AmneziaVpnKey {
  const AmneziaVpnKey({
    required this.name,
    required this.serviceType,
    required this.serviceProtocol,
    required this.userCountryCode,
    required this.apiKey,
  });

  final String name;

  final String serviceType;

  final String serviceProtocol;

  final String userCountryCode;

  final String apiKey;

  bool get isValid => apiKey.isNotEmpty && serviceType.isNotEmpty;
}

Map<String, dynamic>? decodeAmneziaEnvelope(String text) {
  var body = text.trim();
  if (body.isEmpty) return null;
  if (body.toLowerCase().startsWith('vpn://')) body = body.substring(6);
  if (body.startsWith('{')) return _asJsonObject(body);

  final bytes = _decodeBase64Url(body);
  if (bytes == null || bytes.length < 5) return null;

  // Skip the 4-byte qCompress length prefix; premium keys overwrite it with a
  // constant, so it is never read.
  final inflated = _inflate(bytes.sublist(4));
  final text0 = inflated ?? bytes;
  try {
    return _asJsonObject(utf8.decode(text0, allowMalformed: false));
  } on FormatException {
    return null;
  }
}

AmneziaVpnKey? parseAmneziaVpnKey(String text) {
  final doc = decodeAmneziaEnvelope(text);
  if (doc == null) return null;
  if (!_isGatewayKey(doc)) return null;

  final api = doc['api_config'];
  final auth = doc['auth_data'];
  if (api is! Map || auth is! Map) return null;
  final key = AmneziaVpnKey(
    name: '${doc['name'] ?? L10n.current.configKindSubscriptionPlain}',
    serviceType: '${api['service_type'] ?? ''}',
    serviceProtocol: '${api['service_protocol'] ?? ''}',
    userCountryCode: '${api['user_country_code'] ?? ''}',
    apiKey: '${auth['api_key'] ?? ''}',
  );
  return key.isValid ? key : null;
}

bool _isGatewayKey(Map<String, dynamic> doc) =>
    doc['config_version'] == 2 && doc['api_config'] is Map;

Map<String, dynamic>? _asJsonObject(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

Uint8List? _decodeBase64Url(String input) {
  var s = input
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  s = s.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
  s = s.replaceAll('=', '');
  final pad = (4 - s.length % 4) % 4;
  if (pad == 3) return null;
  try {
    return base64.decode(s + '=' * pad);
  } on FormatException {
    return null;
  }
}

Uint8List? _inflate(Uint8List body) {
  try {
    return Uint8List.fromList(ZLibCodec().decode(body));
  } catch (_) {
    return null;
  }
}
