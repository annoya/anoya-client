import 'dart:convert';
import 'dart:io';

import '../amnezia/secondary_config.dart';
import '../log.dart';
import '../mihomo_tun_config.dart';
import '../norm_config.dart';
import 'mihomo_proxy.dart';
import 'subscription.dart';

final _interfaceHeader = RegExp(
  r'^\s*\[Interface\]\s*$',
  multiLine: true,
  caseSensitive: false,
);

bool looksLikeWireGuardConfig(String text) => _interfaceHeader.hasMatch(text);

ParsedSubscription? parseWireGuardConfig(String text) {
  if (!looksLikeWireGuardConfig(text)) return null;
  final sections = _sections(text);
  final iface = sections['interface']?.first ?? const {};
  final peer = sections['peer']?.first ?? const {};
  final location = _location(text, iface, peer);
  if (location == null) {
    return const ParsedSubscription(
      locations: [],
      format: SubscriptionFormat.wireguard,
    );
  }
  return ParsedSubscription(
    locations: [location],
    dns: _dns(iface['DNS']),
    routing: allowedIpsRouting(peer['AllowedIPs']),
    format: SubscriptionFormat.wireguard,
  );
}

Map<String, List<Map<String, String>>> _sections(String text) {
  final out = <String, List<Map<String, String>>>{};
  Map<String, String>? current;
  for (final raw in const LineSplitter().convert(text)) {
    final hash = raw.indexOf('#');
    final line = (hash < 0 ? raw : raw.substring(0, hash)).trim();
    if (line.isEmpty) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      final name = line.substring(1, line.length - 1).trim().toLowerCase();
      out.putIfAbsent(name, () => []).add(current = {});
      continue;
    }
    final eq = line.indexOf('=');
    if (current == null || eq < 0) continue;
    final value = line.substring(eq + 1).trim();
    current.update(
      line.substring(0, eq).trim(),
      (v) => '$v,$value',
      ifAbsent: () => value,
    );
  }
  return out;
}

Location? _location(
  String text,
  Map<String, String> iface,
  Map<String, String> peer,
) {
  final privateKey = iface['PrivateKey'] ?? '';
  final publicKey = peer['PublicKey'] ?? '';
  final psk = peer['PresharedKey'] ?? '';
  final endpoint = _endpoint(peer['Endpoint'] ?? '');
  final (v4, v6) = _addresses(iface['Address']);
  if (!_isKey(privateKey) ||
      !_isKey(publicKey) ||
      (psk.isNotEmpty && !_isKey(psk)) ||
      endpoint == null ||
      (v4 == null && v6 == null)) {
    Log.e('wireguard: config skipped', 'missing key, endpoint or address');
    return null;
  }
  final awg = amneziaWgOptions(iface);
  final amnezia = awg.keys.any((k) => k != 'version');
  final mtu =
      int.tryParse(iface['MTU'] ?? '') ?? (amnezia ? kAmneziaMtu : null);
  final keepalive = int.tryParse(peer['PersistentKeepalive'] ?? '') ?? 0;
  return locationFor(text, labelOr('', endpoint.host, endpoint.port), {
    'type': 'wireguard',
    'server': endpoint.host,
    'port': endpoint.port,
    'private-key': privateKey,
    'public-key': publicKey,
    if (psk.isNotEmpty) 'pre-shared-key': psk,
    'ip': ?v4,
    'ipv6': ?v6,
    'mtu': ?mtu,
    if (keepalive > 0) 'persistent-keepalive': keepalive,
    'udp': true,
    if (amnezia) 'amnezia-wg-option': awg,
  }, description: amnezia ? 'AmneziaWG' : 'WireGuard');
}

bool _isKey(String s) {
  try {
    return base64.decode(s).length == 32;
  } on FormatException {
    return false;
  }
}

({String host, int port})? _endpoint(String raw) {
  final colon = raw.lastIndexOf(':');
  if (colon <= 0) return null;
  final host = bareHost(raw.substring(0, colon).trim());
  final port = int.tryParse(raw.substring(colon + 1).trim()) ?? 0;
  if (host.isEmpty || port < 1 || port > 65535) return null;
  return (host: host, port: port);
}

(String?, String?) _addresses(String? raw) {
  String? v4, v6;
  for (final e in (raw ?? '').split(',')) {
    final ip = InternetAddress.tryParse(e.split('/').first.trim());
    if (ip == null) continue;
    if (ip.type == InternetAddressType.IPv4) {
      v4 ??= ip.address;
    } else {
      v6 ??= ip.address;
    }
  }
  return (v4, v6);
}

List<String> _dns(String? raw) => [
  for (final e in (raw ?? '').split(','))
    if (InternetAddress.tryParse(e.trim()) case final ip?)
      '${ip.address}#$kTunnelOutbound',
];
