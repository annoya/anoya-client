import 'dart:io';

import 'engine_config_text.dart';
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
    // Both families are handled, not just claimed. The tunnel owns the v6
    // default route (ADR-002), so v6 has to work end to end here — with the
    // engine's v6 off, the fake-ip pool would refuse AAAA and every v6
    // destination would fail instead of being carried.
    'ipv6: true',
    // Resolving a connection's owning process is only needed for PROCESS-NAME
    // rules; otherwise keep it off (it reads other processes' info).
    hasProcessRules ? 'find-process-mode: strict' : 'find-process-mode: "off"',
    // Geo rules read geoip.metadb / GeoSite.dat from the engine home dir (the
    // app downloads them there). The engine must never fetch them itself:
    // `geo-auto-update: false` only stops periodic refreshes, but a missing or
    // unverifiable database makes mihomo download it *while parsing the
    // config*, with a 90-second timeout per file — inside startTunnel that
    // overruns the system's tunnel-start deadline, and on a hot reload it
    // holds the engine lock for the duration. Empty source URLs turn that into
    // an immediate parse failure instead (measured: 2 ms, no request), which
    // keeps the previous config running and leaves the app the only
    // downloader. Emitted always, so the policy does not depend on which rules
    // a configuration happens to carry.
    'geox-url:',
    "  geoip: ''",
    "  geosite: ''",
    "  mmdb: ''",
    "  asn: ''",
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
    '  fake-ip-range: $kFakeIpRange',
    '  fake-ip-range6: $kFakeIpRange6',
    // A resolver addressed by hostname (DoH/DoT by name) needs a plain-IP
    // bootstrap, or the engine would need DNS to set up DNS.
    if (nameservers.any(_dnsNeedsBootstrap)) ...[
      '  default-nameserver:',
      '    - 1.1.1.1',
    ],
    '  nameserver:',
    for (final ns in nameservers) '    - ${yamlScalar(ns)}',
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
    // Pinned rather than left to the engine's default: this line is part of
    // what Tun.Equal compares, so an upstream default that changed under us
    // would turn the next hot switch into a listener re-creation — i.e. a
    // dropped session. The address is the engine's own documented default.
    '  inet6-address:',
    '    - $kTunInet6Address',
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

/// Fake-IP pools. The engine answers DNS from these ranges and maps the
/// address back to the domain when the connection arrives, so what leaves the
/// device is a hostname, not one of these addresses.
///
/// App constants, never per-config: the OS caches the fake addresses the
/// engine handed out, so a range that moved on a hot switch would strand every
/// cached answer. The v4 range is the engine's default (RFC 2544 benchmarking
/// space, unroutable on purpose); the v6 range is ULA space (RFC 4193), which
/// has no engine default — mihomo requires one once IPv6 is on.
const kFakeIpRange = '198.18.0.1/16';
const kFakeIpRange6 = 'fc00::/18';

/// The v6 address of the engine's own TUN stack. The Network Extension assigns
/// the interface's addresses; this is what the userspace stack answers on, and
/// it must exist for the stack to accept v6 packets at all.
const kTunInet6Address = 'fdfe:dcba:9876::1/126';

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
  // A subscription proxy is already mihomo-shaped and spells this
  // `reality-opts`, so the two never collide — but check for that key too,
  // because taking this branch discards every other field the subscription set.
  if (p['reality'] is Map && p['reality-opts'] == null) {
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
    final key = yamlKey(k);
    if (v is Map) {
      out.add('$pad$key:');
      out.addAll(_mapLines(v.cast<String, dynamic>(), indent + 2));
    } else if (v is List) {
      out.add('$pad$key:');
      for (final e in v) {
        out.add('${' ' * (indent + 2)}- ${yamlScalar(e)}');
      }
    } else {
      out.add('$pad$key: ${yamlScalar(v)}');
    }
  });
  return out;
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
