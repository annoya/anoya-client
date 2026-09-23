import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../l10n/l10n.dart';

/// The `vpn://` key an Amnezia subscription is handed out as.
///
/// It is a Qt artefact and decodes like one: URL-safe base64 over a
/// `qCompress` payload, which is a four-byte big-endian length prefix followed
/// by a raw zlib stream. Amnezia's own premium encoder overwrites that prefix
/// with a constant signature, so the number is not to be trusted — only its
/// width. Both cases decode the same way: skip four bytes, inflate.
///
/// The same codec unwraps the `config` field of a `/v1/config` answer, which
/// is the same envelope nested one level down.
class AmneziaVpnKey {
  const AmneziaVpnKey({
    required this.name,
    required this.serviceType,
    required this.serviceProtocol,
    required this.userCountryCode,
    required this.apiKey,
  });

  final String name;

  /// `amnezia-premium`, `amnezia-free`, or `external-premium`.
  final String serviceType;

  /// The protocol the service was issued for: `awg` or `vless`. A location can
  /// offer others, and the user may switch — this is only the starting point.
  final String serviceProtocol;

  /// Where the *user* is, as the issuer understood it. Not where the server
  /// is; it steers which bypass proxies are fetched.
  final String userCountryCode;

  /// The subscription's bearer credential. Never logged, never rendered.
  final String apiKey;

  bool get isValid => apiKey.isNotEmpty && serviceType.isNotEmpty;
}

/// Decodes a `vpn://` key, or any bare base64 body in that envelope.
///
/// Returns null when the text is not an Amnezia key at all — which is a
/// routine answer, since every pasted string is offered to every parser.
Map<String, dynamic>? decodeAmneziaEnvelope(String text) {
  var body = text.trim();
  if (body.isEmpty) return null;
  if (body.toLowerCase().startsWith('vpn://')) body = body.substring(6);
  // Already plain JSON: Amnezia accepts a pasted document as readily as a key.
  if (body.startsWith('{')) return _asJsonObject(body);

  final bytes = _decodeBase64Url(body);
  if (bytes == null || bytes.length < 5) return null;

  // Four bytes of length prefix — a real one from qCompress, or the constant
  // Amnezia substitutes for premium keys. Neither is worth reading.
  final inflated = _inflate(bytes.sublist(4));
  final text0 = inflated ?? bytes;
  try {
    return _asJsonObject(utf8.decode(text0, allowMalformed: false));
  } on FormatException {
    return null;
  }
}

/// Reads a decoded document as a gateway subscription. Null when it is one of
/// the shapes we deliberately do not serve.
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

/// Which Amnezia dialect a decoded document is.
///
/// `config_version` is the discriminator their own client uses: 2 is the
/// gateway subscription this app supports, 1 is the retired format that even
/// Amnezia refuses now, and anything else is a self-hosted server bundle. We
/// serve only the first — the app has its own self-hosted domain, and it is
/// not this one.
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

/// Qt's decoder is lenient about both alphabet and padding, and keys travel
/// through chat apps and QR codes, so ours has to be too.
Uint8List? _decodeBase64Url(String input) {
  var s = input
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  s = s.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
  s = s.replaceAll('=', '');
  final pad = (4 - s.length % 4) % 4;
  if (pad == 3) return null; // never a valid base64 length
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
    // Not compressed: the encoder skips compression when it does not pay, and
    // the reader is expected to notice rather than be told.
    return null;
  }
}
