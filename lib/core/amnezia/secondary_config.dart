import 'dart:convert';

import '../norm_config.dart';
import '../parsers/subscription.dart';
import 'vpn_key.dart';

/// What one `/v1/config` answer turned into: a server this app can run, plus
/// the resolvers the config came with.
class AmneziaSecondaryConfig {
  const AmneziaSecondaryConfig({
    required this.location,
    required this.dns,
    required this.expiresAt,
  });

  final Location location;
  final List<String> dns;

  /// When the issued key stops being accepted, as the gateway stated it. Null
  /// when it said nothing — which is not "never", only "unknown", so the
  /// caller treats it as a config that never goes stale on a clock.
  final DateTime? expiresAt;
}

/// Turns a `/v1/config` answer into something the engine can run.
///
/// The answer is an Amnezia server document nested one envelope deeper: the
/// `config` field is another `vpn://` payload, and inside it the actual
/// protocol settings are a JSON *string* under `last_config`. Both layers are
/// unwrapped here so nothing downstream has to know Amnezia's packaging.
///
/// [privateKey] is substituted for the placeholder the gateway leaves behind.
/// It never travelled to them and must not be logged on the way back.
AmneziaSecondaryConfig? parseAmneziaSecondaryConfig(
  Map<String, dynamic> response, {
  required String label,
  required String privateKey,
}) {
  final wrapped = response['config'];
  if (wrapped is! String || wrapped.isEmpty) return null;
  var text = wrapped;
  // The placeholder appears in both the .conf text and the key field, so the
  // substitution is done on the whole document before it is parsed.
  if (privateKey.isNotEmpty) {
    text = text.replaceAll(_privateKeyPlaceholder, privateKey);
  }
  final doc = decodeAmneziaEnvelope(text);
  if (doc == null) return null;
  final patched = privateKey.isEmpty
      ? doc
      : jsonDecode(jsonEncode(doc)
          .replaceAll(_privateKeyPlaceholder, privateKey)) as Map<String, dynamic>;

  final containers = patched['containers'];
  if (containers is! List) return null;

  final dns = <String>[
    for (final k in const ['dns1', 'dns2'])
      if (patched[k] is String && (patched[k] as String).isNotEmpty) patched[k] as String,
  ];

  for (final container in containers) {
    if (container is! Map) continue;
    final awg = container['awg'] ?? container['wireguard'];
    if (awg is Map) {
      final loc = _awgLocation(patched, awg.cast<String, dynamic>(), label);
      if (loc != null) {
        return AmneziaSecondaryConfig(
          location: loc,
          dns: dns,
          expiresAt: _expiry(patched),
        );
      }
    }
    final xray = container['xray'];
    if (xray is Map) {
      final loc = _xrayLocation(xray.cast<String, dynamic>(), label);
      if (loc != null) {
        return AmneziaSecondaryConfig(
          location: loc,
          dns: dns,
          expiresAt: _expiry(patched),
        );
      }
    }
  }
  return null;
}

const _privateKeyPlaceholder = r'$WIREGUARD_CLIENT_PRIVATE_KEY';

DateTime? _expiry(Map<String, dynamic> doc) {
  final api = doc['api_config'];
  if (api is! Map) return null;
  final pk = api['public_key'];
  if (pk is! Map) return null;
  return DateTime.tryParse('${pk['expires_at'] ?? ''}')?.toUtc();
}

/// AmneziaWG as a mihomo `wireguard` outbound.
///
/// The obfuscation parameters ride in `amnezia-wg-option`, which the engine
/// supports natively — H1–H4 arrive as ranges ("a-b") rather than numbers,
/// which is the v2+ form and is why those four are strings on both sides.
Location? _awgLocation(
    Map<String, dynamic> doc, Map<String, dynamic> awg, String label) {
  final raw = awg['last_config'];
  if (raw is! String) return null;
  final Map<String, dynamic> cfg;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    cfg = decoded.cast<String, dynamic>();
  } on FormatException {
    return null;
  }

  final server = '${cfg['hostName'] ?? doc['hostName'] ?? ''}';
  final port = int.tryParse('${cfg['port'] ?? awg['port'] ?? ''}') ?? 0;
  final privateKey = '${cfg['client_priv_key'] ?? ''}';
  final publicKey = '${cfg['server_pub_key'] ?? ''}';
  if (server.isEmpty || port == 0 || privateKey.isEmpty || publicKey.isEmpty) {
    return null;
  }
  // The placeholder survived: the gateway issued a config we have no private
  // half for, and running it would fail a handshake for no stated reason.
  if (privateKey.contains(_privateKeyPlaceholder)) return null;

  final proxy = <String, dynamic>{
    'type': 'wireguard',
    'server': server,
    'port': port,
    'private-key': privateKey,
    'public-key': publicKey,
    if ('${cfg['psk_key'] ?? ''}'.isNotEmpty) 'pre-shared-key': cfg['psk_key'],
    // The tunnel address, without the mask the .conf writes it with.
    if ('${cfg['client_ip'] ?? ''}'.isNotEmpty)
      'ip': '${cfg['client_ip']}'.split('/').first,
    if (int.tryParse('${cfg['mtu'] ?? ''}') != null) 'mtu': int.parse('${cfg['mtu']}'),
    if (int.tryParse('${cfg['persistent_keep_alive'] ?? ''}') != null)
      'persistent-keepalive': int.parse('${cfg['persistent_keep_alive']}'),
    // WireGuard carries datagrams by nature, and saying so is what lets a
    // resolver be pinned through this tunnel at all (ADR-008).
    'udp': true,
  };

  final awgOpts = _amneziaOptions(cfg);
  if (awgOpts.isNotEmpty) proxy['amnezia-wg-option'] = awgOpts;

  return Location(id: 'amnezia', label: label, proxy: proxy);
}

/// The obfuscation set, in the engine's spelling.
///
/// Only what the gateway actually sent is emitted: an obfuscation parameter
/// defaulted on our side is a different protocol than the server is speaking.
Map<String, dynamic> _amneziaOptions(Map<String, dynamic> cfg) {
  final out = <String, dynamic>{};
  void number(String from, String to) {
    final v = int.tryParse('${cfg[from] ?? ''}');
    if (v != null && v != 0) out[to] = v;
  }

  void text(String from, String to) {
    final v = '${cfg[from] ?? ''}';
    if (v.isNotEmpty && v != 'null') out[to] = v;
  }

  number('Jc', 'jc');
  number('Jmin', 'jmin');
  number('Jmax', 'jmax');
  number('S1', 's1');
  number('S2', 's2');
  number('S3', 's3');
  number('S4', 's4');
  // Magic headers arrive as ranges ("5-758037243") in AWG 2+, so they stay
  // text on both sides rather than being parsed into something narrower.
  for (final h in const ['H1', 'H2', 'H3', 'H4']) {
    text(h, h.toLowerCase());
  }
  for (final i in const ['I1', 'I2', 'I3', 'I4', 'I5']) {
    text(i, i.toLowerCase());
  }
  // J1–J3 and Itime are deliberately not forwarded: they are deprecated, only
  // the engine's legacy port knows them, and passing one would both pin us to
  // that port and be rejected by the current one.
  // AWG 3.1 adds these; older servers send none of them and must not be given
  // defaults, so each is copied only when present.
  const v3 = {
    'HeaderProtectionKey': 'header-protection-key',
    'ContentPaddingAddition': 'content-padding-addition',
    'RekeyAfterTime': 'rekey-after-time',
    'RekeyTimeout': 'rekey-timeout',
    'RejectAfterTime': 'reject-after-time',
    'KeepaliveTimeout': 'keepalive-timeout',
    'MaxHandshakeAttempts': 'max-handshake-attempts',
    'RandomTrailers': 'random-trailers',
    'DisableCookies': 'disable-cookies',
  };
  for (final e in v3.entries) {
    text(e.key, e.value);
  }
  // Always the current implementation.
  //
  // The engine carries two AmneziaWG ports and picks between them on this
  // number alone: `device` at 3, `device_v1` at anything else. They are not a
  // version ladder — both accept the whole set Amnezia issues (jc/jmin/jmax,
  // s1–s4, h1–h4, i1–i5) and put it on the wire differently — so "it parsed"
  // says nothing about having chosen right. What separates them is only the
  // deprecated j1–j3/itime on one side and the header-protection family on the
  // other, and Amnezia's servers speak the current protocol.
  out['version'] = 3;
  return out;
}

/// VLESS arrives as an ordinary Xray document, which this app already reads.
/// Reusing that parser rather than writing a second one is the point: an
/// Amnezia VLESS server and a panel's VLESS server differ in where they came
/// from, not in what they are.
Location? _xrayLocation(Map<String, dynamic> xray, String label) {
  final raw = xray['last_config'];
  if (raw is! String) return null;
  final parsed = parseSubscription(raw);
  if (parsed.isEmpty) return null;
  final first = parsed.first;
  return Location(id: 'amnezia', label: label, proxy: first.proxy);
}
