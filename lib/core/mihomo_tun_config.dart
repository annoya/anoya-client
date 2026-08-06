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
  String stack = 'gvisor',
  bool collectLogs = true,
}) {
  final proxy = _mihomoProxy(location);
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
    '  enhanced-mode: fake-ip',
    '  fake-ip-range: 198.18.0.1/16',
    '  nameserver:',
    '    - https://1.1.1.1/dns-query',
    'tun:',
    '  enable: true',
    '  stack: $stack',
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
