import 'dart:convert';

import '../norm_config.dart';
import '../parsers/subscription.dart';
import 'vpn_key.dart';

class AmneziaSecondaryConfig {
  const AmneziaSecondaryConfig({
    required this.location,
    required this.dns,
    required this.expiresAt,
  });

  final Location location;
  final List<String> dns;

  final DateTime? expiresAt;
}

AmneziaSecondaryConfig? parseAmneziaSecondaryConfig(
  Map<String, dynamic> response, {
  required String label,
  required String privateKey,
}) {
  final wrapped = response['config'];
  if (wrapped is! String || wrapped.isEmpty) return null;
  var text = wrapped;
  // Substituted before parsing: the placeholder is in both the .conf text and
  // the key field.
  if (privateKey.isNotEmpty) {
    text = text.replaceAll(_privateKeyPlaceholder, privateKey);
  }
  final doc = decodeAmneziaEnvelope(text);
  if (doc == null) return null;
  final patched = privateKey.isEmpty
      ? doc
      : jsonDecode(
              jsonEncode(doc).replaceAll(_privateKeyPlaceholder, privateKey),
            )
            as Map<String, dynamic>;

  final containers = patched['containers'];
  if (containers is! List) return null;

  final dns = <String>[
    for (final k in const ['dns1', 'dns2'])
      if (patched[k] is String && (patched[k] as String).isNotEmpty)
        patched[k] as String,
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

Location? _awgLocation(
  Map<String, dynamic> doc,
  Map<String, dynamic> awg,
  String label,
) {
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
  if (privateKey.contains(_privateKeyPlaceholder)) return null;

  final proxy = <String, dynamic>{
    'type': 'wireguard',
    'server': server,
    'port': port,
    'private-key': privateKey,
    'public-key': publicKey,
    if ('${cfg['psk_key'] ?? ''}'.isNotEmpty) 'pre-shared-key': cfg['psk_key'],
    if ('${cfg['client_ip'] ?? ''}'.isNotEmpty)
      'ip': '${cfg['client_ip']}'.split('/').first,
    if (int.tryParse('${cfg['mtu'] ?? ''}') != null)
      'mtu': int.parse('${cfg['mtu']}'),
    if (int.tryParse('${cfg['persistent_keep_alive'] ?? ''}') != null)
      'persistent-keepalive': int.parse('${cfg['persistent_keep_alive']}'),
    'udp': true,
  };

  final awgOpts = _amneziaOptions(cfg);
  if (awgOpts.isNotEmpty) proxy['amnezia-wg-option'] = awgOpts;

  return Location(id: 'amnezia', label: label, proxy: proxy);
}

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
  // AWG 2+ sends H1-H4 as ranges ("5-758037243"), so they stay strings.
  for (final h in const ['H1', 'H2', 'H3', 'H4']) {
    text(h, h.toLowerCase());
  }
  for (final i in const ['I1', 'I2', 'I3', 'I4', 'I5']) {
    text(i, i.toLowerCase());
  }
  // J1-J3/Itime deliberately not forwarded: only the engine's legacy port
  // accepts them. AWG 3.1 fields are copied only when present, never defaulted.
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
  // Always 3: the engine picks its AmneziaWG port on this number alone
  // (`device` at 3, `device_v1` otherwise), and servers speak the current one.
  out['version'] = 3;
  return out;
}

Location? _xrayLocation(Map<String, dynamic> xray, String label) {
  final raw = xray['last_config'];
  if (raw is! String) return null;
  final parsed = parseSubscription(raw);
  if (parsed.isEmpty) return null;
  final first = parsed.first;
  return Location(id: 'amnezia', label: label, proxy: first.proxy);
}
