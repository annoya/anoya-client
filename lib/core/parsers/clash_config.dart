import 'package:yaml/yaml.dart';

import '../engine_config_text.dart';
import '../log.dart';
import '../mihomo_tun_config.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'subscription.dart';

/// Clash / mihomo YAML, the second shape a subscription body arrives in.
///
/// Unlike a share link, the proxy entries here are already mihomo-shaped maps
/// with keys chosen by whoever wrote the document — which is why key sanitation
/// (AGENTS invariant 5) lives in this file and not in the renderer alone.

ParsedSubscription? parseClashProxies(String body) {
  final hasProxies = RegExp(r'(^|\n)\s*proxies\s*:').hasMatch(body);
  final hasProviders = RegExp(r'(^|\n)\s*proxy-providers\s*:').hasMatch(body);
  if (!hasProxies && !hasProviders) return null;
  try {
    final doc = loadYaml(body);
    if (doc is! Map) return null;
    if (doc['proxies'] is! List && doc['proxy-providers'] is! Map) return null;
    final out = <Location>[];
    final unsupported = <String, int>{};
    var i = 0;
    for (final p in (doc['proxies'] as List? ?? const [])) {
      final m = _deepConvert(p);
      if (m is! Map<String, dynamic> || m['type'] == null || m['server'] == null) continue;
      final type = m['type'].toString();
      // Filtered here rather than left to the renderer: an entry we cannot
      // render would otherwise reach the server picker and fail only when the
      // user taps Connect, which is the worst possible moment to find out.
      if (!kSupportedProxyTypes.contains(type)) {
        unsupported[type] = (unsupported[type] ?? 0) + 1;
        continue;
      }
      final name = m['name']?.toString() ?? '${m['server']}:${m['port']}';
      out.add(Location(id: 'sub_${i++}_${shortDigest(name)}', label: name, proxy: m));
    }
    final providers = _proxyProviders(doc['proxy-providers']);
    final groups = _proxyGroups(doc['proxy-groups'], out);
    // No early return on an empty result: a document with `proxies: []` is
    // recognisably Clash, and a panel does answer that way (an expired account,
    // a full device limit). Calling it "a format we cannot read" would send the
    // user to fix the one thing that is not wrong.
    return ParsedSubscription(
      locations: out,
      unsupported: unsupported,
      providers: providers,
      groups: groups,
      format: SubscriptionFormat.clash,
    );
  } catch (e) {
    Log.e('clash yaml parse failed', '$e');
    return null;
  }
}


/// Reads `proxy-groups:` — the sets whose member the engine picks.
///
/// Members are resolved to the servers we actually parsed, so a group naming a
/// proxy we cannot run comes out smaller, and one left with nothing comes out
/// not at all: offering a choice that cannot work is worse than not offering it.
List<ProxyGroup> _proxyGroups(Object? node, List<Location> locations) {
  if (node is! List) return const [];
  final byName = {for (final l in locations) l.label: l.id};
  final out = <ProxyGroup>[];
  for (final raw in node) {
    final g = _deepConvert(raw);
    if (g is! Map<String, dynamic>) continue;
    final type = '${g['type'] ?? ''}'.toLowerCase();
    // `select` is a human's choice, which our own picker already is.
    if (!ProxyGroup.types.contains(type)) continue;

    // `include-all` (and its older spellings) means "every proxy in this
    // document" — the shape Remnawave's own template uses.
    final all = g['include-all'] == true ||
        g['include-all-proxies'] == true ||
        g['include-all-providers'] == true;
    final named = (g['proxies'] as List? ?? const []).map((e) => '$e').toList();
    final members = all
        ? locations.map((l) => l.id).toList()
        : [for (final n in named) if (byName[n] != null) byName[n]!];

    final group = ProxyGroup(
      name: '${g['name'] ?? ''}'.trim(),
      type: type,
      members: members,
      testUrl: '${g['url'] ?? ''}',
      intervalSeconds: (g['interval'] as num?)?.toInt() ?? 0,
      tolerance: (g['tolerance'] as num?)?.toInt() ?? 0,
      strategy: ProxyGroup.strategies.contains('${g['strategy'] ?? ''}')
          ? '${g['strategy']}'
          : '',
    );
    if (group.isValid) out.add(group);
  }
  return out;
}

/// Reads `proxy-providers:` — server lists the document does not carry itself
/// but points at.
///
/// Declared here, fetched by the layer that owns the network: a parser that
/// starts making requests is a parser you cannot test without one. Only remote
/// providers survive — `file` points at the author's own disk, and `inline`
/// carries its payload in a document we did not receive.
List<ProxyProvider> _proxyProviders(Object? node) {
  if (node is! Map) return const [];
  final out = <ProxyProvider>[];
  node.forEach((name, spec) {
    if (spec is! Map) return;
    if ('${spec['type']}' != 'http') return;
    final p = ProxyProvider(name: '$name', url: '${spec['url'] ?? ''}');
    if (p.isValid) out.add(p);
  });
  return out;
}

/// Resolvers a Clash/mihomo-YAML subscription ships in `dns.nameserver`;
/// empty for link lists and anything unparseable. Mined separately from the
/// proxies because our tunnel config keeps its own dns block (fake-ip range
/// and mode are app constants) and adopts only the resolvers.
List<String> subscriptionDns(String body) {
  final trimmed = body.trim();
  if (!RegExp(r'(^|\n)\s*dns\s*:').hasMatch(trimmed)) return const [];
  try {
    final doc = loadYaml(trimmed);
    if (doc is! Map) return const [];
    final dns = doc['dns'];
    if (dns is! Map) return const [];
    final ns = dns['nameserver'];
    if (ns is! List) return const [];
    return [
      for (final e in ns)
        if (e != null && '$e'.trim().isNotEmpty) '$e'.trim(),
    ];
  } catch (e) {
    Log.e('subscription dns parse failed', '$e');
    return const [];
  }
}


/// Recursively converts YamlMap/YamlList into plain `Map<String,dynamic>`/List.
///
/// A Clash/mihomo-YAML subscription is attacker-supplied (ADR-005), and its map
/// keys flow into the engine config we render. A key carrying a newline would
/// break out of its block and add top-level keys (`external-controller`,
/// `allow-lan`…), so keys that are not plainly a config key are dropped here —
/// the drop-not-escape stance ADR-003/ADR-008 take for values, extended to keys.
dynamic _deepConvert(dynamic node) {
  if (node is YamlMap || node is Map) {
    final out = <String, dynamic>{};
    for (final e in (node as Map).entries) {
      final k = e.key.toString();
      if (!isSafeConfigKey(k)) {
        Log.e('clash yaml: dropped unsafe proxy key', k.replaceAll('\n', r'\n'));
        continue;
      }
      out[k] = _deepConvert(e.value);
    }
    return out;
  }
  if (node is YamlList || node is List) {
    return [for (final e in (node as List)) _deepConvert(e)];
  }
  return node;
}

