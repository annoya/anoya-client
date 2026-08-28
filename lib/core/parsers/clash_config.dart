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
      dns: _dnsServers(doc['dns']),
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

    // A group that names its membership by pattern and is read without the
    // patterns is not a smaller mistake than a missing group — it is a larger
    // one. On the live subscription `exclude-filter: 🇷🇺|🏳️` is the provider
    // saying "not through a Russian exit", and a group built without it sends
    // the user exactly where they were being steered away from. So a pattern we
    // cannot compile drops the group rather than widening it.
    final List<RegExp>? keep, drop;
    try {
      keep = _patterns(g['filter']);
      drop = _patterns(g['exclude-filter']);
    } on FormatException catch (e) {
      Log.e('clash yaml: group filter is not a pattern we can run',
          '${g['name']}: $e');
      continue;
    }
    final byId = {for (final l in locations) l.id: l};
    // Explicit names first, then what `include-all` adds, matching the engine's
    // own order. The filter applies only to the second half: mihomo skips it for
    // an explicit list ("compatible provider unneeded filter").
    final picked = <String>[
      for (final n in named) ?byName[n],
      if (all)
        for (final l in locations)
          if (keep == null || keep.any((r) => r.hasMatch(l.label))) l.id,
    ];
    final members = <String>[];
    for (final id in picked) {
      if (members.contains(id)) continue;
      // `exclude-filter` is applied to the whole membership however it was
      // assembled, which is what the engine does in `GroupBase.GetProxies`.
      final label = byId[id]?.label ?? '';
      if (drop != null && drop.any((r) => r.hasMatch(label))) continue;
      if (_excludedType(g['exclude-type'], byId[id])) continue;
      members.add(id);
    }

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

/// Resolvers a Clash/mihomo-YAML subscription ships in `dns.nameserver`.
///
/// The only format that already speaks the target syntax, so the entries pass
/// through as written — including a `#pin`, which here names one of the
/// provider's own proxy groups and is judged by the renderer against the
/// outbounds we actually define. What does not pass through is the rest of the
/// block: our `dns:` section owns fake-ip and the bootstrap, and adopting a
/// foreign `enhanced-mode` would strand every fake address the OS has cached.
List<String> _dnsServers(Object? node) {
  if (node is! Map) return const [];
  final ns = node['nameserver'];
  if (ns is! List) return const [];
  final out = <String>[];
  for (final e in ns) {
    final s = '${e ?? ''}'.trim();
    if (s.isNotEmpty && !out.contains(s)) out.add(s);
  }
  return out;
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

/// The name patterns a group's `filter` / `exclude-filter` holds.
///
/// mihomo splits the field on a backtick and treats each part as its own
/// regular expression, matching if any of them does. The dialect is .NET
/// (`regexp2`) rather than Dart's; the shapes panels actually use — alternation
/// over flags and country emoji — are common to both, and the one construct
/// that turns up and does not exist here is the inline `(?i)`, which is the
/// same request as a case-insensitive match.
///
/// Throws [FormatException] when a part will not compile, because the caller
/// must not carry on with a membership the provider did not describe.
List<RegExp>? _patterns(Object? node) {
  final raw = '${node ?? ''}'.trim();
  if (raw.isEmpty) return null;
  final out = <RegExp>[];
  for (final part in raw.split('`')) {
    if (part.isEmpty) continue;
    var body = part;
    var sensitive = true;
    if (body.startsWith('(?i)')) {
      body = body.substring(4);
      sensitive = false;
    }
    out.add(RegExp(body, caseSensitive: sensitive));
  }
  return out.isEmpty ? null : out;
}

/// `exclude-type: vless|hysteria2` — the same statement as `exclude-filter`,
/// made about the protocol instead of the name, and just as wrong to ignore.
bool _excludedType(Object? node, Location? location) {
  final raw = '${node ?? ''}'.trim();
  if (raw.isEmpty || location == null) return false;
  return raw.split('|').map((t) => t.trim().toLowerCase()).contains(location.proxyType);
}
