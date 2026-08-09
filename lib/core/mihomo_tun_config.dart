import 'dart:io';

import 'log.dart';
import 'norm_config.dart';

/// Builds a mihomo config for Network Extension mode: a TUN inbound (the
/// extension binds it to the utun fd) instead of a local mixed-port proxy.
/// Routing into the tun is done by the NE network settings; mihomo reads the
/// fd, applies rules, and egresses via the selected proxy.
///
/// [routing] is the split-tunneling policy (managed or device-local); null
/// means "everything through the VPN".
///
/// [dns] is the resolver list the config ships with (mihomo nameserver
/// syntax); empty falls back to Cloudflare DoH. It rides the same YAML as
/// everything else, so switching configs switches DNS too.
///
/// [stack] is the mihomo TUN network stack — "gvisor" on both macOS and iOS
/// (fully userspace; the only stack that works inside the NE sandbox).
///
/// Supports vless / vmess / trojan / ss. The selected location's `proxy` is
/// either the self-hosted vless+reality shape (custom `reality` key) or a
/// mihomo-format map (from a share link / subscription); both are normalized
/// to a single mihomo proxy here. Pure + top-level so it can be unit-tested.
String mihomoTunConfigYaml(
  Location location, {
  Routing? routing,
  List<String> dns = const [],
  String stack = 'gvisor',
  bool collectLogs = true,
}) {
  final proxy = _mihomoProxy(location);
  final nameservers = _dnsNameservers(dns);
  final ruleLines = _routingRuleLines(routing);
  final hasProcessRules =
      routing?.rules.any((r) => r.type == 'process-name' && r.isValid) ?? false;
  final hasGeoRules = routing?.rules.any((r) => r.needsGeoData && r.isValid) ?? false;
  final lines = <String>[
    // "silent" is how the engine stops writing at all: the log file is in the
    // extension's container, so there is no other way to keep it quiet.
    collectLogs ? 'log-level: info' : 'log-level: silent',
    'mode: rule',
    'ipv6: false',
    // Resolving a connection's owning process is only needed for PROCESS-NAME
    // rules; otherwise keep it off (it reads other processes' info).
    hasProcessRules ? 'find-process-mode: strict' : 'find-process-mode: "off"',
    // Geo rules read geoip.metadb / GeoSite.dat from the engine home dir (the
    // app downloads them there). Never let the engine self-download: a 20+ MB
    // fetch during tunnel start would hang connects.
    if (hasGeoRules) ...[
      'geodata-mode: false',
      'geo-auto-update: false',
    ],
    'dns:',
    '  enable: true',
    // fake-ip settings are app constants, never per-config: the OS caches the
    // fake addresses it handed out, so a range that moved on a hot switch
    // would strand every cached answer.
    '  enhanced-mode: fake-ip',
    '  fake-ip-range: 198.18.0.1/16',
    // A resolver addressed by hostname (DoH/DoT by name) needs a plain-IP
    // bootstrap, or the engine would need DNS to set up DNS.
    if (nameservers.any(_dnsNeedsBootstrap)) ...[
      '  default-nameserver:',
      '    - 1.1.1.1',
    ],
    '  nameserver:',
    for (final ns in nameservers) '    - ${_scalar(ns)}',
    'tun:',
    '  enable: true',
    '  stack: $stack',
    // Without this the engine forwards ICMP with a DIRECT outbound of its own
    // — it opens a socket on the physical interface, so `ping` while the VPN is
    // up leaks the real address (the request enters the tun and leaves again
    // outside it). Disabled, the stack answers echo requests itself and nothing
    // escapes.
    '  disable-icmp-forwarding: true',
    '  dns-hijack:',
    '    - any:53',
    // NE owns OS routing; mihomo just reads the fd. Detect the physical
    // interface so the proxy's own outbound does not loop back into the tun.
    '  auto-route: false',
    '  auto-detect-interface: true',
    '  mtu: 9000',
    'proxies:',
    ..._emitProxy(proxy),
    'proxy-groups:',
    '  - name: PROXY',
    '    type: select',
    '    proxies: [proxy]',
    'rules:',
    ...ruleLines,
    // Unmatched traffic: full mode tunnels it, split mode sends it direct.
    if (routing?.mode == 'split') '  - MATCH,DIRECT' else '  - MATCH,PROXY',
  ];
  return '${lines.join('\n')}\n';
}

const _supportedProxyTypes = {'vless', 'vmess', 'trojan', 'ss'};

/// Normalizes a Location's proxy into a single mihomo proxy map named "proxy".
/// The self-hosted bundle uses a custom `reality` sub-map; share-link and
/// subscription proxies are already mihomo-shaped (see proxy_uri.dart).
Map<String, dynamic> _mihomoProxy(Location location) {
  final type = location.proxyType;
  if (!_supportedProxyTypes.contains(type)) {
    throw StateError('unsupported proxy type: $type');
  }
  final p = location.proxy;
  // Self-hosted vless+reality shape → mihomo keys (matches the old output).
  if (p['reality'] is Map) {
    final r = Map<String, dynamic>.from(p['reality'] as Map);
    final m = <String, dynamic>{
      'name': 'proxy',
      'type': 'vless',
      'server': p['server'],
      'port': p['port'],
      'uuid': p['uuid'],
      'network': 'tcp',
      'udp': true,
      'tls': p['tls'] ?? true,
    };
    if ((p['flow'] as String?)?.isNotEmpty ?? false) m['flow'] = p['flow'];
    m['servername'] = r['server_name'];
    m['client-fingerprint'] = 'chrome';
    m['reality-opts'] = {'public-key': r['public_key'], 'short-id': r['short_id']};
    return m;
  }
  // Already a mihomo proxy map — clone with name forced to "proxy".
  final m = <String, dynamic>{'name': 'proxy'};
  for (final e in p.entries) {
    if (e.key != 'name') m[e.key] = e.value;
  }
  return m;
}

/// Emits a mihomo proxy map as YAML block-list lines under `proxies:`. All
/// string scalars are double-quoted (safe against special chars in
/// uuids/paths/passwords); bools/numbers stay unquoted. Nested maps (ws-opts,
/// reality-opts…) are supported.
List<String> _emitProxy(Map<String, dynamic> proxy) {
  final body = _mapLines(proxy, 4);
  body[0] = '  - ${body[0].substring(4)}'; // first key becomes the list item
  return body;
}

List<String> _mapLines(Map<String, dynamic> m, int indent) {
  final pad = ' ' * indent;
  final out = <String>[];
  m.forEach((k, v) {
    if (v is Map) {
      out.add('$pad$k:');
      out.addAll(_mapLines(v.cast<String, dynamic>(), indent + 2));
    } else if (v is List) {
      out.add('$pad$k:');
      for (final e in v) {
        out.add('${' ' * (indent + 2)}- ${_scalar(e)}');
      }
    } else {
      out.add('$pad$k: ${_scalar(v)}');
    }
  });
  return out;
}

String _scalar(dynamic v) {
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return v.toString();
  final s = v.toString().replaceAll('\\', r'\\').replaceAll('"', r'\"');
  return '"$s"';
}

const _ruleTypeMap = {
  'domain-suffix': 'DOMAIN-SUFFIX',
  'domain-keyword': 'DOMAIN-KEYWORD',
  'domain-exact': 'DOMAIN',
  'ip-cidr': 'IP-CIDR',
  'process-name': 'PROCESS-NAME',
  'geoip': 'GEOIP',
  'geosite': 'GEOSITE',
};

const _actionMap = {'proxy': 'PROXY', 'direct': 'DIRECT', 'block': 'REJECT'};

/// Renders ordered routing rules to mihomo rule lines. Invalid rules are
/// skipped (and logged), never interpolated: values come from the server or
/// the local editor, and a malformed one must not corrupt the YAML.
List<String> _routingRuleLines(Routing? routing) {
  if (routing == null) return const [];
  final out = <String>[];
  for (final r in routing.rules) {
    final type = _ruleTypeMap[r.type];
    final action = _actionMap[r.action];
    if (type == null || action == null || !r.isValid) {
      Log.e('routing: skipping invalid rule', '${r.type},${r.value},${r.action}');
      continue;
    }
    // no-resolve: IP-based rules must not force DNS resolution of domain
    // traffic. Always on for ip-cidr; opt-in per geoip rule.
    final suffix =
        (r.type == 'ip-cidr' || (r.type == 'geoip' && r.noResolve)) ? ',no-resolve' : '';
    final value = r.type == 'geoip' ? r.value.toUpperCase() : r.value;
    out.add('  - $type,$value,$action$suffix');
  }
  return out;
}

/// The config's own resolvers, sanitized, or the Cloudflare DoH fallback when
/// it names none. Entries land inside the engine YAML and can come from a
/// subscription we don't control, so anything that couldn't be a nameserver —
/// whitespace, quotes, non-ASCII — is dropped and logged, never escaped into
/// the document.
List<String> _dnsNameservers(List<String> dns) {
  final out = <String>[];
  for (final raw in dns) {
    final ns = raw.trim();
    if (ns.isEmpty) continue;
    if (RegExp(r'[^\x21-\x7e]').hasMatch(ns) || ns.contains('"') || ns.contains(r'\')) {
      Log.e('dns: skipping unusable nameserver', raw);
      continue;
    }
    out.add(ns);
  }
  return out.isEmpty ? const ['https://1.1.1.1/dns-query'] : out;
}

/// True when the nameserver is addressed by hostname (https://dns.google/…)
/// rather than by IP. Understands the mihomo forms: plain IP, host:port,
/// scheme URLs, an optional `#ADAPTER` suffix, and the `system`/`dhcp://`
/// pseudo-resolvers (which never need bootstrapping).
bool _dnsNeedsBootstrap(String ns) {
  final s = ns.split('#').first;
  if (s == 'system') return false;
  String host;
  if (s.contains('://')) {
    final u = Uri.tryParse(s);
    if (u == null || u.scheme == 'dhcp') return false;
    host = u.host;
  } else if (InternetAddress.tryParse(s) != null) {
    return false; // bare IP, IPv6 colons included
  } else if (s.startsWith('[') && s.contains(']')) {
    host = s.substring(1, s.indexOf(']'));
  } else {
    host = s.split(':').first;
  }
  return host.isNotEmpty && InternetAddress.tryParse(host) == null;
}
