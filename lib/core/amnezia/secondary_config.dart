import 'dart:convert';

import '../log.dart';
import '../mihomo_tun_config.dart';
import '../norm_config.dart';
import '../parsers/subscription.dart';
import 'vpn_key.dart';

class AmneziaSecondaryConfig {
  const AmneziaSecondaryConfig({
    required this.location,
    required this.dns,
    required this.expiresAt,
    this.routing,
  });

  final Location location;
  final List<String> dns;

  final Routing? routing;

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
        '${patched[k]}#$kTunnelOutbound',
  ];

  for (final container in containers) {
    if (container is! Map) continue;
    final awg = container['awg'] ?? container['wireguard'];
    if (awg is Map) {
      final awgCfg = _awgLocation(patched, awg.cast<String, dynamic>(), label);
      if (awgCfg != null) {
        return AmneziaSecondaryConfig(
          location: awgCfg.location,
          dns: dns,
          expiresAt: _expiry(patched),
          routing: awgCfg.routing,
        );
      }
    }
    final xray = container['xray'];
    if (xray is Map) {
      final xrayCfg = _xrayLocation(xray.cast<String, dynamic>(), label);
      if (xrayCfg != null) {
        return AmneziaSecondaryConfig(
          location: xrayCfg.location,
          dns: dns,
          expiresAt: _expiry(patched),
          routing: xrayCfg.routing,
        );
      }
    }
  }
  return null;
}

const _amneziaMtu = 1376;

const _privateKeyPlaceholder = r'$WIREGUARD_CLIENT_PRIVATE_KEY';

DateTime? _expiry(Map<String, dynamic> doc) {
  final api = doc['api_config'];
  if (api is! Map) return null;
  final pk = api['public_key'];
  if (pk is! Map) return null;
  return DateTime.tryParse('${pk['expires_at'] ?? ''}')?.toUtc();
}

({Location location, Routing? routing})? _awgLocation(
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
    'mtu': int.tryParse('${cfg['mtu'] ?? awg['mtu'] ?? ''}') ?? _amneziaMtu,
    if (int.tryParse('${cfg['persistent_keep_alive'] ?? ''}') != null)
      'persistent-keepalive': int.parse('${cfg['persistent_keep_alive']}'),
    'udp': true,
  };

  final awgOpts = _amneziaOptions(cfg);
  if (awgOpts.isNotEmpty) proxy['amnezia-wg-option'] = awgOpts;

  return (
    location: Location(id: 'amnezia', label: label, proxy: proxy),
    routing: allowedIpsRouting(cfg['allowed_ips']),
  );
}

Routing? allowedIpsRouting(Object? allowed) {
  final raw = switch (allowed) {
    List() => allowed.map((e) => '$e'),
    String() => allowed.split(','),
    _ => const <String>[],
  };
  final nets = [
    for (final e in raw.map((e) => e.trim()).where((e) => e.isNotEmpty))
      _cidr(e),
  ];
  if (nets.isEmpty || nets.contains('0.0.0.0/0')) return null;
  final valid = [
    for (final n in nets)
      if (RoutingRule.isValidValue('ip-cidr', n)) n,
  ];
  if (valid.length < nets.length) {
    Log.e('amnezia: allowed_ips entries skipped', nets.length - valid.length);
  }
  if (valid.isEmpty) return null;
  return Routing(
    mode: 'split',
    rules: [RoutingRule(type: 'ip-cidr', values: valid, action: 'proxy')],
  );
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
  // The engine picks its AmneziaWG port on this number alone (`device` at 3).
  out['version'] = 3;
  return out;
}

({Location location, Routing? routing})? _xrayLocation(
  Map<String, dynamic> xray,
  String label,
) {
  final raw = xray['last_config'];
  if (raw is! String) return null;
  final parsed = parseSubscription(raw);
  if (parsed.isEmpty) return null;
  final first = parsed.first;
  Object? config;
  try {
    config = jsonDecode(raw);
  } on FormatException {
    config = null;
  }
  return (
    location: Location(id: 'amnezia', label: label, proxy: first.proxy),
    routing: xrayRouting(config),
  );
}

Routing? xrayRouting(Object? config) {
  if (config is! Map) return null;
  final outbounds = config['outbounds'];
  final routing = config['routing'];
  final xrayRules = routing is Map ? routing['rules'] : null;
  if (outbounds is! List || xrayRules is! List) return null;
  final actions = <String, String?>{};
  String? fallback;
  for (final ob in outbounds.whereType<Map>()) {
    final action = switch ('${ob['protocol'] ?? ''}'.toLowerCase()) {
      'freedom' => 'direct',
      'blackhole' => 'block',
      'dns' || 'loopback' => null,
      _ => 'proxy',
    };
    actions.putIfAbsent('${ob['tag'] ?? ''}', () => action);
    fallback ??= action;
  }
  final rules = <RoutingRule>[];
  var skipped = 0;
  for (final r in xrayRules.whereType<Map>()) {
    final action = r['balancerTag'] != null
        ? 'proxy'
        : actions['${r['outboundTag'] ?? ''}'];
    if (action == null) continue;
    final fields = {for (final k in r.keys) '$k'}
      ..removeAll(const {'type', 'outboundTag', 'balancerTag', 'ruleTag'});
    if (fields.every(const {'network', 'port'}.contains) && _matchesAll(r)) {
      fallback = action;
      break;
    }
    if (fields.length != 1 || !const {'ip', 'domain'}.contains(fields.first)) {
      skipped++;
      continue;
    }
    final field = fields.first;
    final byType = <String, List<String>>{};
    for (final v in r[field] is List ? r[field] as List : const []) {
      final match = field == 'ip' ? _xrayIp('$v') : _xrayDomain('$v');
      if (match == null || !RoutingRule.isValidValue(match.type, match.value)) {
        skipped++;
        continue;
      }
      byType.putIfAbsent(match.type, () => []).add(match.value);
    }
    for (final MapEntry(key: type, value: values) in byType.entries) {
      rules.add(RoutingRule(type: type, values: values, action: action));
    }
  }
  if (skipped > 0) Log.e('amnezia: xray routing entries skipped', skipped);
  final mode = switch (fallback) {
    'direct' => 'split',
    'proxy' || null => 'full',
    _ => null,
  };
  if (mode == null ||
      mode == 'full' && rules.every((r) => r.action == 'proxy')) {
    return null;
  }
  return Routing(mode: mode, rules: rules);
}

bool _matchesAll(Map rule) {
  final network = '${rule['network'] ?? 'tcp,udp'}'.toLowerCase();
  final port = '${rule['port'] ?? '0-65535'}'.replaceAll(' ', '');
  return network.contains('tcp') &&
      network.contains('udp') &&
      (port == '0-65535' || port == '1-65535');
}

({String type, String value})? _xrayIp(String v) {
  final e = v.trim();
  if (e.startsWith('geoip:')) {
    final code = e.substring(6);
    return code.startsWith('!') ? null : (type: 'geoip', value: code);
  }
  if (e.startsWith('ext:')) return null;
  return (type: 'ip-cidr', value: _cidr(e));
}

({String type, String value})? _xrayDomain(String v) {
  final e = v.trim();
  final colon = e.indexOf(':');
  final (prefix, rest) = colon < 0
      ? ('', e)
      : (e.substring(0, colon), e.substring(colon + 1));
  final type = switch (prefix) {
    'domain' => 'domain-suffix',
    'full' => 'domain-exact',
    'keyword' || '' => 'domain-keyword',
    'regexp' => 'domain-regex',
    'geosite' => 'geosite',
    _ => null,
  };
  return type == null ? null : (type: type, value: rest);
}

String _cidr(String e) =>
    e.contains('/') ? e : '$e/${e.contains(':') ? 128 : 32}';
