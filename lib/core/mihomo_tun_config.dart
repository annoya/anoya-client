import 'dns_plan.dart';
import 'engine_config_text.dart';
import 'log.dart';
import 'norm_config.dart';

String mihomoTunConfigYaml(
  Location location, {
  ProxyGroup? group,
  List<Location> members = const [],
  Routing? routing,
  List<String> dns = const [],
  String defaultDns = kFallbackNameserver,
  Map<String, String> listPaths = const {},
  bool collectLogs = true,
  bool autoDetectInterface = true,
  String? device,
  String? dnsDecoy,
  int mtu = kTunMtu,
}) {
  final proxy = _mihomoProxy(location);
  final proxyLines = <String>[];
  final groupLines = <String>[];
  final rendered = <Map<String, dynamic>>[];
  final String entry;
  if (group == null) {
    rendered.add(proxy);
    proxyLines.addAll(_emitProxy(proxy));
    entry = 'proxy';
  } else {
    for (var i = 0; i < members.length; i++) {
      final m = {..._mihomoProxy(members[i]), 'name': 'p$i'};
      rendered.add(m);
      proxyLines.addAll(_emitProxy(m));
    }
    groupLines.addAll(_emitGroup(group, members.length));
    entry = kGroupName;
  }
  final shape = engineShape(location, group: group, members: members);
  final plan = dnsPlanFor(
    dns: dns,
    outbounds: shape.outbounds,
    carriesUdp: shape.carriesUdp,
    fallback: defaultDns,
  );
  final ruleLines = _routingRuleLines(routing, listPaths);
  final listLines = _ruleProviderLines(routing, listPaths);
  final hasProcessRules =
      routing?.rules.any((r) => r.type == 'process-name' && r.isValid) ?? false;
  final hasGeoRules =
      routing?.rules.any((r) => r.needsGeoData && r.isValid) ?? false;
  final lines = <String>[
    collectLogs ? 'log-level: debug' : 'log-level: silent',
    'mode: rule',
    'profile:',
    '  store-fake-ip: true',
    'ipv6: true',
    hasProcessRules ? 'find-process-mode: strict' : 'find-process-mode: "off"',
    // Empty URLs stop mihomo downloading a missing database mid-startTunnel.
    'geox-url:',
    "  geoip: ''",
    "  geosite: ''",
    "  mmdb: ''",
    "  asn: ''",
    if (hasGeoRules) ...['geodata-mode: false', 'geo-auto-update: false'],
    'dns:',
    '  enable: true',
    '  enhanced-mode: fake-ip',
    '  fake-ip-range: $kFakeIpRange',
    '  fake-ip-range6: $kFakeIpRange6',
    if (plan.needsBootstrapNameserver) ...[
      '  default-nameserver:',
      '    - 1.1.1.1',
    ],
    '  proxy-server-nameserver:',
    for (final ns in plan.bootstrap) '    - ${yamlScalar(ns)}',
    '  nameserver:',
    for (final r in plan.resolvers) '    - ${yamlScalar(r.wire)}',
    'sniffer:',
    '  enable: true',
    '  force-dns-mapping: true',
    '  parse-pure-ip: true',
    '  override-destination: false',
    '  sniff:',
    '    HTTP:',
    '      ports: [80, 8080-8880]',
    '    TLS:',
    '      ports: [443, 8443]',
    '    QUIC:',
    '      ports: [443, 8443]',
    'tun:',
    '  enable: true',
    if (device != null) '  device: ${yamlScalar(device)}',
    if (device != null) '  stack: mixed' else '  stack: gvisor',
    '  disable-icmp-forwarding: true',
    '  dns-hijack:',
    '    - any:53',
    '  inet6-address:',
    '    - $kTunInet6Address',
    '  auto-route: ${device != null}',
    // Windows Smart Multi-Homed Name Resolution also queries the ISP resolver.
    if (device != null) '  strict-route: true',
    // Android bans netlink since 11; VpnService.protect() avoids loops instead.
    '  auto-detect-interface: $autoDetectInterface',
    '  mtu: $mtu',
    'proxies:',
    ...proxyLines,
    'proxy-groups:',
    ...groupLines,
    '  - name: $kTunnelOutbound',
    '    type: select',
    '    proxies: [$entry]',
    ...listLines,
    'rules:',
    // Refusing the decoy makes Android's Private DNS probe fall back to plain DNS.
    if (dnsDecoy != null) '  - IP-CIDR,$dnsDecoy/32,REJECT,no-resolve',
    ...ruleLines,
    if (routing?.mode == 'split') '  - MATCH,DIRECT' else '  - MATCH,PROXY',
  ];
  return '${lines.join('\n')}\n';
}

({Set<String> outbounds, bool carriesUdp}) engineShape(
  Location location, {
  ProxyGroup? group,
  List<Location> members = const [],
}) {
  final shapeless = group == null
      ? location.isPlaceholder
      : members.isEmpty || members.any((m) => m.isPlaceholder);
  if (shapeless) {
    return (outbounds: <String>{'DIRECT', 'REJECT'}, carriesUdp: false);
  }
  final rendered = group == null
      ? [_mihomoProxy(location)]
      : [for (final m in members) _mihomoProxy(m)];
  return (
    outbounds: <String>{
      kTunnelOutbound,
      'DIRECT',
      'REJECT',
      if (group == null)
        'proxy'
      else ...[
        kGroupName,
        for (var i = 0; i < members.length; i++) 'p$i',
      ],
    },
    carriesUdp: rendered.isNotEmpty && rendered.every((p) => p['udp'] == true),
  );
}

const kGroupName = 'group';

const kTunnelOutbound = 'PROXY';

const kMinGroupInterval = Duration(minutes: 5);

List<String> _emitGroup(ProxyGroup group, int memberCount) {
  final out = <String>['  - name: $kGroupName', '    type: ${group.type}'];
  if (group.type == 'load-balance' && group.strategy.isNotEmpty) {
    out.add('    strategy: ${group.strategy}');
  }
  if (group.type != 'relay') {
    final url = Uri.tryParse(group.testUrl);
    final safe = url != null && url.scheme == 'https' && url.host.isNotEmpty
        ? group.testUrl
        : kDefaultGroupTestUrl;
    out.add('    url: ${yamlScalar(safe)}');
    final asked = Duration(seconds: group.intervalSeconds);
    final interval = asked < kMinGroupInterval ? kMinGroupInterval : asked;
    out.add('    interval: ${interval.inSeconds}');
    if (group.type == 'url-test' && group.tolerance > 0) {
      out.add('    tolerance: ${group.tolerance}');
    }
  }
  out.add(
    '    proxies: [${[for (var i = 0; i < memberCount; i++) 'p$i'].join(', ')}]',
  );
  return out;
}

const kDefaultGroupTestUrl = 'https://cp.cloudflare.com/generate_204';

const kFakeIpRange = '198.18.0.1/16';
const kFakeIpRange6 = 'fc00::/18';

const kTunInet6Address = 'fdfe:dcba:9876::1/126';

const kTunMtu = 1500;

const kAndroidTunMtu = 9000;

const kAndroidDnsDecoy = '172.19.0.2';

const kSupportedProxyTypes = {
  'vless',
  'vmess',
  'trojan',
  'ss',
  'hysteria2',
  'wireguard',
};

const kSubscriptionProxyTypes = {'vless', 'vmess', 'trojan', 'ss', 'hysteria2'};

Map<String, dynamic> _mihomoProxy(Location location) {
  final type = location.proxyType;
  if (location.isPlaceholder) {
    throw StateError(
      'this server has no settings yet — it must be issued '
      'before it can be rendered (ADR-009)',
    );
  }
  if (!kSupportedProxyTypes.contains(type)) {
    throw StateError('unsupported proxy type: $type');
  }
  final p = location.proxy;
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
    m['reality-opts'] = {
      'public-key': r['public_key'],
      'short-id': r['short_id'],
    };
    return m;
  }
  final m = <String, dynamic>{'name': 'proxy'};
  for (final e in p.entries) {
    if (e.key != 'name') m[e.key] = e.value;
  }
  return m;
}

List<String> _emitProxy(Map<String, dynamic> proxy) {
  final body = _mapLines(proxy, 4);
  body[0] = '  - ${body[0].substring(4)}';
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
  'domain-regex': 'DOMAIN-REGEX',
  'ip-cidr': 'IP-CIDR',
  'process-name': 'PROCESS-NAME',
  'geoip': 'GEOIP',
  'geosite': 'GEOSITE',
  'rule-list': 'RULE-SET',
};

const _actionMap = {'proxy': 'PROXY', 'direct': 'DIRECT', 'block': 'REJECT'};

const _inlineBehavior = {
  'domain-suffix': 'domain',
  'domain-exact': 'domain',
  'ip-cidr': 'ipcidr',
};

bool _inlined(RoutingRule r) =>
    r.values.length > 1 && _inlineBehavior.containsKey(r.type);

String _inlineName(int index) => '_inline_$index';

List<String> _ruleProviderLines(Routing? routing, Map<String, String> paths) {
  if (routing == null) return const [];
  final used = routing.rules
      .where((r) => r.needsRuleList && r.isValid && paths.containsKey(r.value))
      .map((r) => r.value)
      .toSet();
  final out = <String>['rule-providers:'];
  for (final name in used) {
    final list = routing.listNamed(name);
    if (list == null || !list.isValid) continue;
    out.addAll([
      '  ${yamlKey(name)}:',
      '    type: file',
      '    path: ${yamlScalar(paths[name])}',
      '    behavior: ${list.behavior}',
      '    format: ${list.format}',
    ]);
  }
  for (final (i, r) in routing.rules.indexed) {
    if (!_inlined(r) || !r.isValid || _actionMap[r.action] == null) continue;
    out.addAll([
      '  ${_inlineName(i)}:',
      '    type: inline',
      '    behavior: ${_inlineBehavior[r.type]}',
      '    payload:',
      for (final v in r.values)
        '      - ${yamlScalar(r.type == 'domain-suffix' ? '+.$v' : v)}',
    ]);
  }
  return out.length == 1 ? const [] : out;
}

List<String> _routingRuleLines(
  Routing? routing, [
  Map<String, String> paths = const {},
]) {
  if (routing == null) return const [];
  final out = <String>[];
  for (final (i, r) in routing.rules.indexed) {
    final type = _ruleTypeMap[r.type];
    final action = _actionMap[r.action];
    if (r.needsRuleList && !paths.containsKey(r.value)) {
      Log.e('routing: skipping rule-list rule', 'no local copy of ${r.value}');
      continue;
    }
    if (type == null || action == null || !r.isValid) {
      Log.e(
        'routing: skipping invalid rule',
        '${r.type},${r.values.join(' ')},${r.action}',
      );
      continue;
    }
    final suffix =
        (r.type == 'ip-cidr' ||
            ((r.type == 'geoip' || r.type == 'rule-list') && r.noResolve))
        ? ',no-resolve'
        : '';
    if (_inlined(r)) {
      out.add('  - RULE-SET,${_inlineName(i)},$action$suffix');
      continue;
    }
    for (final v in r.values) {
      final value = r.type == 'geoip' ? v.toUpperCase() : v;
      out.add('  - $type,$value,$action$suffix');
    }
  }
  return out;
}
