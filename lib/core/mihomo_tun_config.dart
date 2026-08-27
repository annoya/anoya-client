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
/// [group] and [members] render a provider's group instead of a single server:
/// every member becomes a proxy and the group decides which of them carries the
/// traffic. [location] is ignored then.
///
/// [listPaths] maps a `rule-list` rule's name to the file the app downloaded
/// for it. A rule whose list is absent here is dropped: the engine would
/// happily accept a provider it has to fetch itself, and that fetch runs inside
/// config apply with a 20 s timeout per file, then fails by only logging —
/// leaving a rule that matches nothing at all.
///
/// [stack] is the mihomo TUN network stack — "gvisor" on both macOS and iOS
/// (fully userspace; the only stack that works inside the NE sandbox).
///
/// Supports vless / vmess / trojan / ss / hysteria2. The selected location's `proxy` is
/// either the self-hosted vless+reality shape (custom `reality` key) or a
/// mihomo-format map (from a share link / subscription); both are normalized
/// to a single mihomo proxy here. Pure + top-level so it can be unit-tested.
String mihomoTunConfigYaml(
  Location location, {
  ProxyGroup? group,
  List<Location> members = const [],
  Routing? routing,
  List<String> dns = const [],
  Map<String, String> listPaths = const {},
  String stack = 'gvisor',
  bool collectLogs = true,
}) {
  final proxy = _mihomoProxy(location);
  final nameservers = _dnsNameservers(dns);
  // A single server, or a group whose member the engine picks. Either way the
  // rules keep pointing at PROXY: what changes is what PROXY contains, so the
  // rest of the config — and the `tun` section above all — is untouched.
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
  // mihomo's `udp` is off unless the proxy says otherwise, and a datagram dial
  // through an outbound that cannot carry one is an error, not a fallback.
  final carriesUdp = rendered.isNotEmpty && rendered.every((p) => p['udp'] == true);
  // Every outbound name this config actually defines, so a nameserver pinned to
  // an adapter can be checked against something instead of being trusted.
  final outbounds = <String>{
    kTunnelOutbound,
    'DIRECT',
    'REJECT',
    if (group == null) 'proxy' else ...[
      kGroupName,
      for (var i = 0; i < members.length; i++) 'p$i',
    ],
  };
  final kept = [
    for (final ns in nameservers) ?_dnsForQueries(ns, outbounds, carriesUdp),
  ];
  // Dropping an uncarryable resolver can empty the list, and an empty
  // `nameserver:` is not "no opinion" to the engine — it is a resolver list of
  // none, which answers nothing.
  final queryServers = kept.isEmpty ? const [kFallbackNameserver] : kept;
  final bootstrapServers = <String>{for (final ns in nameservers) _dnsUnpinned(ns)};
  final ruleLines = _routingRuleLines(routing, listPaths);
  final listLines = _ruleProviderLines(routing, listPaths);
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
    if (bootstrapServers.any(_dnsNeedsBootstrap)) ...[
      '  default-nameserver:',
      '    - 1.1.1.1',
    ],
    // The proxy's own address is usually a hostname, and resolving it must
    // never depend on the proxy. Without this block mihomo resolves proxy
    // hostnames with the main resolver, so a subscription whose nameserver is
    // pinned to the tunnel (`...#PROXY`, which panels ship to keep DNS off the
    // local network) deadlocks: the query needs the tunnel, the tunnel needs
    // the query, and every dial fails with "couldn't find ip" — a connected
    // VPN that carries nothing. `default-nameserver` does not rescue it; the
    // engine only uses that to resolve a *nameserver's* own hostname.
    // Same resolvers as below, minus the pin: the provider's choice of
    // resolver is kept, only the loop is cut.
    '  proxy-server-nameserver:',
    for (final ns in bootstrapServers) '    - ${yamlScalar(ns)}',
    '  nameserver:',
    for (final ns in queryServers) '    - ${yamlScalar(ns)}',
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
    ...proxyLines,
    'proxy-groups:',
    ...groupLines,
    '  - name: $kTunnelOutbound',
    '    type: select',
    '    proxies: [$entry]',
    ...listLines,
    'rules:',
    ...ruleLines,
    // Unmatched traffic: full mode tunnels it, split mode sends it direct.
    if (routing?.mode == 'split') '  - MATCH,DIRECT' else '  - MATCH,PROXY',
  ];
  return '${lines.join('\n')}\n';
}

/// The name the rendered group takes. Ours, not the provider's: the provider's
/// name is display text and can hold anything, while this ends up as a YAML key
/// and a rule target.
const kGroupName = 'group';

/// The one outbound every rendered config has, whatever the source: the select
/// group the rules point at. Public because the subscription parsers translate
/// a source's "send this through the proxy" into a pin on this name — the
/// provider's own outbound names do not survive into our config.
const kTunnelOutbound = 'PROXY';

/// Resolver schemes mihomo knows (`config/config.go`, `parseNameServer`). An
/// unknown one is not skipped by the engine — it fails the *whole* config, so
/// one exotic entry in a subscription's `dns:` block would cost every server
/// and every rule. Anything with no scheme at all is fine: the engine reads it
/// as `udp://`.
const kMihomoDnsSchemes = {
  'udp',
  'tcp',
  'tls',
  'http',
  'https',
  'quic',
  'system',
  'dhcp',
  'rcode',
  'ts',
  'tailscale',
};

/// The engine's own health check runs from the user's device, through the
/// tunnel, once per interval per member. A provider asking for ten seconds
/// would have a phone probing their URL 8640 times a day; the floor is ours to
/// set, and mihomo's `lazy` default (skip a round when nothing used the group)
/// already covers idle time.
const kMinGroupInterval = Duration(minutes: 5);

/// Renders the provider's group. Members are named `p0…pN` rather than by their
/// own labels: a label is the provider's text, and these are YAML keys.
List<String> _emitGroup(ProxyGroup group, int memberCount) {
  final out = <String>[
    '  - name: $kGroupName',
    '    type: ${group.type}',
  ];
  if (group.type == 'load-balance' && group.strategy.isNotEmpty) {
    out.add('    strategy: ${group.strategy}');
  }
  if (group.type != 'relay') {
    // relay chains its members and has nothing to measure.
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
  out.add('    proxies: [${[for (var i = 0; i < memberCount; i++) 'p$i'].join(', ')}]');
  return out;
}

/// Where the engine measures a member when the provider named nothing usable.
/// A 204 endpoint, because the check is about reaching the internet at all.
const kDefaultGroupTestUrl = 'https://cp.cloudflare.com/generate_204';

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

/// Proxy types this renderer can turn into an engine config. Public because
/// the subscription parsers consult it: keeping a proxy we cannot render would
/// put a server in the picker that fails only when the user taps Connect.
const kSupportedProxyTypes = {'vless', 'vmess', 'trojan', 'ss', 'hysteria2'};

/// Normalizes a Location's proxy into a single mihomo proxy map named "proxy".
/// The self-hosted bundle uses a custom `reality` sub-map; share-link and
/// subscription proxies are already mihomo-shaped (see proxy_uri.dart).
Map<String, dynamic> _mihomoProxy(Location location) {
  final type = location.proxyType;
  if (!kSupportedProxyTypes.contains(type)) {
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
  'domain-regex': 'DOMAIN-REGEX',
  'ip-cidr': 'IP-CIDR',
  'process-name': 'PROCESS-NAME',
  'geoip': 'GEOIP',
  'geosite': 'GEOSITE',
  'rule-list': 'RULE-SET',
};

const _actionMap = {'proxy': 'PROXY', 'direct': 'DIRECT', 'block': 'REJECT'};

/// Renders the `rule-providers:` block for the lists a policy's `rule-list`
/// rules point at, as local files. `type: file` and nothing else: the engine
/// must not do network at apply time.
List<String> _ruleProviderLines(Routing? routing, Map<String, String> paths) {
  if (routing == null) return const [];
  final used = routing.rules
      .where((r) => r.needsRuleList && r.isValid && paths.containsKey(r.value))
      .map((r) => r.value)
      .toSet();
  if (used.isEmpty) return const [];
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
  return out.length == 1 ? const [] : out;
}

/// Renders ordered routing rules to mihomo rule lines. Invalid rules are
/// skipped (and logged), never interpolated: values come from the server or
/// the local editor, and a malformed one must not corrupt the YAML.
List<String> _routingRuleLines(Routing? routing, [Map<String, String> paths = const {}]) {
  if (routing == null) return const [];
  final out = <String>[];
  for (final r in routing.rules) {
    final type = _ruleTypeMap[r.type];
    final action = _actionMap[r.action];
    // A list rule without its file is a rule that cannot match. Dropping it
    // here is the same choice as for geo rules: the caller has already been
    // told, and a rule that silently matches nothing is worse than one absent.
    if (r.needsRuleList && !paths.containsKey(r.value)) {
      Log.e('routing: skipping rule-list rule', 'no local copy of ${r.value}');
      continue;
    }
    if (type == null || action == null || !r.isValid) {
      Log.e('routing: skipping invalid rule', '${r.type},${r.value},${r.action}');
      continue;
    }
    // no-resolve: IP-based rules must not force DNS resolution of domain
    // traffic. Always on for ip-cidr; opt-in per geoip rule.
    final suffix = (r.type == 'ip-cidr' ||
            ((r.type == 'geoip' || r.type == 'rule-list') && r.noResolve))
        ? ',no-resolve'
        : '';
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
///
/// Only the address is held to that standard. The `#pin` after it is a display
/// name in practice ("🇷🇺 Direct"), and judging the whole string would throw
/// away a perfectly good resolver over the decoration on its end — leaving the
/// provider's DNS silently replaced by ours. [_dnsPinned] decides the pin's
/// fate separately, and only ever keeps one that names an outbound we render.
List<String> _dnsNameservers(List<String> dns) {
  final out = <String>[];
  for (final raw in dns) {
    final ns = raw.trim();
    if (ns.isEmpty) continue;
    final addr = ns.split('#').first;
    if (addr.isEmpty ||
        RegExp(r'[^\x21-\x7e]').hasMatch(addr) ||
        addr.contains('"') ||
        addr.contains(r'\')) {
      Log.e('dns: skipping unusable nameserver', raw);
      continue;
    }
    // A scheme the engine does not know is not a bad entry, it is a bad
    // *config*: mihomo fails the parse and the tunnel never starts, so one
    // `h3://` in a subscription would cost every server and every rule.
    final at = addr.indexOf('://');
    if (at > 0 && !kMihomoDnsSchemes.contains(addr.substring(0, at).toLowerCase())) {
      Log.e('dns: skipping nameserver with a scheme the engine rejects', addr);
      continue;
    }
    if (out.contains(ns)) continue;
    if (out.length >= kMaxNameservers) {
      Log.e('dns: too many resolvers, keeping the first $kMaxNameservers',
          '${dns.length} offered');
      break;
    }
    out.add(ns);
  }
  return out.isEmpty ? const [kFallbackNameserver] : out;
}

/// What a configuration that names no usable resolver gets. Encrypted, so a
/// query that has to leave the tunnel still says nothing to the local network.
const kFallbackNameserver = 'https://1.1.1.1/dns-query';

/// mihomo queries every resolver in the list at once and takes the first
/// answer, so a long list is latency and sockets, not redundancy. Real configs
/// name two or three; this is a ceiling on a body we do not control (ADR-005),
/// not a judgement about a reasonable one.
const kMaxNameservers = 8;

/// A nameserver's `#suffix` pins its queries to one outbound. Null when the
/// entry cannot be sent at all.
///
/// Two things can be wrong with a pin. It can name an outbound we did not
/// render — the provider's own group names, which we replace with ours — and
/// mihomo reads an unknown one as a network *interface* to bind the socket to,
/// sending every query out of a device that isn't there; the pin goes, the
/// resolver stays. Or it can be honourable but uncarryable: a plain `udp://`
/// or `quic://` resolver pinned to an outbound with no UDP support is not a
/// slow query, it is an error on every attempt, and a config whose resolvers
/// all fail that way connects and then resolves nothing — the failure this
/// whole block exists to prevent. There the *resolver* goes, and the encrypted
/// fallback takes over: an unpinned plaintext query would put every domain the
/// user visits on the local network, which is worse than substituting a
/// resolver.
///
/// `RULES` is the engine's own keyword for "route it like traffic" — honoured,
/// and held to the same UDP test, since the rules may well pick the tunnel.
String? _dnsForQueries(String ns, Set<String> outbounds, bool carriesUdp) {
  final at = ns.indexOf('#');
  if (at < 0) return ns;
  final address = ns.substring(0, at);
  final pin = ns.substring(at + 1);
  if (pin != 'RULES' && !outbounds.contains(pin)) {
    Log.e('dns: dropping unknown adapter pin', pin);
    return address;
  }
  if (!carriesUdp && _dnsOverUdp(address)) {
    Log.e('dns: dropping a resolver the tunnel cannot carry', address);
    return null;
  }
  return ns;
}

/// True when reaching this resolver means sending datagrams. No scheme is
/// `udp://` to the engine; QUIC and DHCP are datagrams by construction.
bool _dnsOverUdp(String address) {
  final at = address.indexOf('://');
  if (at < 0) return true;
  final scheme = address.substring(0, at).toLowerCase();
  return scheme == 'udp' || scheme == 'quic' || scheme == 'dhcp';
}

/// The same resolver with no pin at all — reachable without an outbound.
String _dnsUnpinned(String ns) {
  final at = ns.indexOf('#');
  return at < 0 ? ns : ns.substring(0, at);
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
