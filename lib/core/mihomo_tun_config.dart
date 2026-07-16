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
/// [stack] is the mihomo TUN network stack: "gvisor" on macOS (bundled via the
/// with_gvisor build tag), "system" on iOS (lighter — the iOS Network
/// Extension has a hard ~50MB memory cap, and the iOS xcframework slice is
/// built without gVisor).
///
/// Pure + top-level so it can be unit-tested. Only "vless" is implemented.
String mihomoTunConfigYaml(Location location, {Routing? routing, String stack = 'gvisor'}) {
  final p = location.proxy;
  if (location.proxyType != 'vless') {
    throw StateError('unsupported proxy type: ${location.proxyType}');
  }
  final reality = Map<String, dynamic>.from(p['reality'] as Map? ?? {});
  final ruleLines = _routingRuleLines(routing);
  final hasProcessRules =
      routing?.rules.any((r) => r.type == 'process-name' && r.isValid) ?? false;
  final lines = <String>[
    'log-level: info',
    'mode: rule',
    'ipv6: false',
    // Resolving a connection's owning process is only needed for PROCESS-NAME
    // rules; otherwise keep it off (it reads other processes' info).
    hasProcessRules ? 'find-process-mode: strict' : 'find-process-mode: "off"',
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
    '  - name: proxy',
    '    type: vless',
    '    server: ${p['server']}',
    '    port: ${p['port']}',
    '    uuid: ${p['uuid']}',
    '    network: tcp',
    '    udp: true',
    '    tls: ${p['tls'] ?? true}',
    if ((p['flow'] as String?)?.isNotEmpty ?? false) '    flow: ${p['flow']}',
    '    servername: ${reality['server_name']}',
    '    client-fingerprint: chrome',
    '    reality-opts:',
    '      public-key: ${reality['public_key']}',
    '      short-id: "${reality['short_id']}"',
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

const _ruleTypeMap = {
  'domain-suffix': 'DOMAIN-SUFFIX',
  'domain-keyword': 'DOMAIN-KEYWORD',
  'domain-exact': 'DOMAIN',
  'ip-cidr': 'IP-CIDR',
  'process-name': 'PROCESS-NAME',
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
    // no-resolve: IP rules must not force DNS resolution of domain traffic.
    final suffix = r.type == 'ip-cidr' ? ',no-resolve' : '';
    out.add('  - $type,${r.value},$action$suffix');
  }
  return out;
}
