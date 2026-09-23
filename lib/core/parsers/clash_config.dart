import 'package:yaml/yaml.dart';

import '../engine_config_text.dart';
import '../log.dart';
import '../mihomo_tun_config.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'subscription.dart';

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
      if (m is! Map<String, dynamic> ||
          m['type'] == null ||
          m['server'] == null) {
        continue;
      }
      final type = m['type'].toString();
      if (!kSubscriptionProxyTypes.contains(type)) {
        unsupported[type] = (unsupported[type] ?? 0) + 1;
        continue;
      }
      final name = m['name']?.toString() ?? '${m['server']}:${m['port']}';
      out.add(
        Location(id: 'sub_${i++}_${shortDigest(name)}', label: name, proxy: m),
      );
    }
    final providers = _proxyProviders(doc['proxy-providers']);
    final groups = _proxyGroups(doc['proxy-groups'], out);
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

List<ProxyGroup> _proxyGroups(Object? node, List<Location> locations) {
  if (node is! List) return const [];
  final byName = {for (final l in locations) l.label: l.id};
  final out = <ProxyGroup>[];
  for (final raw in node) {
    final g = _deepConvert(raw);
    if (g is! Map<String, dynamic>) continue;
    final type = '${g['type'] ?? ''}'.toLowerCase();
    if (!ProxyGroup.types.contains(type)) continue;

    final all =
        g['include-all'] == true ||
        g['include-all-proxies'] == true ||
        g['include-all-providers'] == true;
    final named = (g['proxies'] as List? ?? const []).map((e) => '$e').toList();

    final List<RegExp>? keep, drop;
    try {
      keep = _patterns(g['filter']);
      drop = _patterns(g['exclude-filter']);
    } on FormatException catch (e) {
      Log.e(
        'clash yaml: group filter is not a pattern we can run',
        '${g['name']}: $e',
      );
      continue;
    }
    final byId = {for (final l in locations) l.id: l};
    final picked = <String>[
      for (final n in named) ?byName[n],
      if (all)
        for (final l in locations)
          if (keep == null || keep.any((r) => r.hasMatch(l.label))) l.id,
    ];
    final members = <String>[];
    for (final id in picked) {
      if (members.contains(id)) continue;
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

dynamic _deepConvert(dynamic node) {
  if (node is YamlMap || node is Map) {
    final out = <String, dynamic>{};
    for (final e in (node as Map).entries) {
      final k = e.key.toString();
      if (!isSafeConfigKey(k)) {
        Log.e(
          'clash yaml: dropped unsafe proxy key',
          k.replaceAll('\n', r'\n'),
        );
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

bool _excludedType(Object? node, Location? location) {
  final raw = '${node ?? ''}'.trim();
  if (raw.isEmpty || location == null) return false;
  return raw
      .split('|')
      .map((t) => t.trim().toLowerCase())
      .contains(location.proxyType);
}
