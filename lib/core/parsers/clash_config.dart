import 'package:yaml/yaml.dart';

import '../clash_plan.dart';
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
      plan: _plan(doc, out),
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

ClashPlan? _plan(Map doc, List<Location> locations) {
  final rawRules = doc['rules'];
  if (rawRules is! List || rawRules.isEmpty) return null;
  final byLabel = {for (final l in locations) l.label: l.id};
  final byId = {for (final l in locations) l.id: l};
  final specials = <String, String>{
    'DIRECT': ClashPlan.direct,
    'REJECT': ClashPlan.block,
    'REJECT-DROP': ClashPlan.block,
  };
  for (final p in (doc['proxies'] as List? ?? const [])) {
    if (p is! Map || p['name'] == null) continue;
    final type = '${p['type'] ?? ''}'.toLowerCase();
    if (type == 'direct') specials['${p['name']}'] = ClashPlan.direct;
    if (type == 'reject') specials['${p['name']}'] = ClashPlan.block;
  }

  final raw = <Map<String, dynamic>>[
    for (final g in (doc['proxy-groups'] as List? ?? const []))
      if (_deepConvert(g) case final Map<String, dynamic> m
          when '${m['name'] ?? ''}'.trim().isNotEmpty &&
              PlanGroup.types.contains('${m['type'] ?? ''}'.toLowerCase()))
        m,
  ];
  final names = {for (final g in raw) '${g['name']}'.trim()};
  String? ref(String entry) =>
      byLabel[entry] ??
      (names.contains(entry) ? ClashPlan.groupRef(entry) : null) ??
      specials[entry];

  var groups = <PlanGroup>[];
  for (final g in raw) {
    final name = '${g['name']}'.trim();
    final List<RegExp>? keep, drop;
    try {
      keep = _patterns(g['filter']);
      drop = _patterns(g['exclude-filter']);
    } on FormatException catch (e) {
      Log.e(
        'clash yaml: group filter is not a pattern we can run',
        '$name: $e',
      );
      continue;
    }
    bool excluded(String id) {
      final l = byId[id];
      if (l == null) return false;
      if (drop != null && drop.any((r) => r.hasMatch(l.label))) return true;
      return _excludedType(g['exclude-type'], l);
    }

    final members = <String>[];
    void add(String? m) {
      if (m == null || m == ClashPlan.groupRef(name)) return;
      if (members.contains(m) || excluded(m)) return;
      members.add(m);
    }

    for (final e in (g['proxies'] as List? ?? const [])) {
      add(ref('$e'));
    }
    if (g['include-all'] == true || g['include-all-proxies'] == true) {
      for (final l in locations) {
        if (keep == null || keep.any((r) => r.hasMatch(l.label))) add(l.id);
      }
    }
    final type = '${g['type']}'.toLowerCase();
    groups.add(
      PlanGroup(
        name: name,
        type: type,
        members: members,
        testUrl: '${g['url'] ?? ''}',
        intervalSeconds: (g['interval'] as num?)?.toInt() ?? 0,
        tolerance: (g['tolerance'] as num?)?.toInt() ?? 0,
        strategy: ProxyGroup.strategies.contains('${g['strategy'] ?? ''}')
            ? '${g['strategy']}'
            : '',
      ),
    );
  }
  groups = _withoutLoops(groups);

  final lists = {
    for (final l in clashRuleLists(doc['rule-providers'])) l.name: l,
  };
  final inline = {
    for (final l in _inlineLists(doc['rule-providers'])) l.name: l,
  };
  final rules = <PlanRule>[];
  var skipped = 0;
  final kept = {for (final g in groups) g.name};
  for (final line in rawRules) {
    final rule = _splitRule('$line');
    final target = rule == null ? null : ref(rule.target);
    final usable =
        rule != null &&
        target != null &&
        (ClashPlan.groupNameOf(target) == null ||
            kept.contains(ClashPlan.groupNameOf(target))) &&
        rule.types.every(kPlanRuleTypes.contains) &&
        rule.options.every(kPlanRuleOptions.contains) &&
        rule.lists.every((l) => lists.containsKey(l) || inline.containsKey(l));
    if (!usable) {
      skipped++;
      continue;
    }
    rules.add(
      PlanRule(
        type: rule.type,
        payload: rule.payload,
        target: target,
        options: rule.options,
      ),
    );
    if (rule.isCatchAll) break;
  }
  if (rules.isEmpty) return null;

  Set<String> servers(String ref, [Set<String>? seen]) {
    seen ??= {};
    final name = ClashPlan.groupNameOf(ref);
    if (name == null) return {ref};
    if (!seen.add(name)) return const {};
    final g = groups.where((g) => g.name == name).firstOrNull;
    return {
      for (final m in g?.members ?? const <String>[]) ...servers(m, seen),
    };
  }

  final dialers = <String, String>{
    for (final l in locations)
      if (ref('${l.proxy['dialer-proxy'] ?? ''}') case final String via
          when (ClashPlan.groupNameOf(via) == null ||
                  kept.contains(ClashPlan.groupNameOf(via))) &&
              !servers(via).contains(l.id))
        l.id: via,
  };
  final reached = <String>{};
  void reach(String ref) {
    final dialer = dialers[ref];
    if (dialer != null) reach(dialer);
    final name = ClashPlan.groupNameOf(ref);
    if (name == null || !reached.add(name)) return;
    final g = groups.firstWhere((g) => g.name == name);
    g.members.forEach(reach);
  }

  for (final r in rules) {
    reach(r.target);
  }
  return ClashPlan(
    groups: [
      for (final g in groups)
        if (reached.contains(g.name)) g,
    ],
    rules: rules,
    lists: [
      for (final l in lists.values)
        if (rules.any((r) => r.lists.contains(l.name))) l,
    ],
    inline: [
      for (final l in inline.values)
        if (rules.any((r) => r.lists.contains(l.name))) l,
    ],
    dialers: dialers,
    skipped: skipped,
  );
}

List<PlanGroup> _withoutLoops(List<PlanGroup> groups) {
  var current = groups;
  while (true) {
    final byName = {for (final g in current) g.name: g};
    final state = <String, int>{};
    final cut = <String, Set<String>>{};
    void visit(String name) {
      state[name] = 1;
      final g = byName[name]!;
      for (final m in g.members) {
        final next = ClashPlan.groupNameOf(m);
        if (next == null || !byName.containsKey(next)) continue;
        if (state[next] == 1) {
          (cut[name] ??= {}).add(m);
        } else if (state[next] == null) {
          visit(next);
        }
      }
      state[name] = 2;
    }

    for (final g in current) {
      if (state[g.name] == null) visit(g.name);
    }
    final live = {
      for (final g in current)
        if (g.members.any(
          (m) =>
              !(cut[g.name]?.contains(m) ?? false) &&
              (ClashPlan.groupNameOf(m) == null ||
                  byName.containsKey(ClashPlan.groupNameOf(m))),
        ))
          g.name,
    };
    bool alive(String m) {
      final name = ClashPlan.groupNameOf(m);
      return name == null || live.contains(name);
    }

    final next = [
      for (final g in current)
        if (live.contains(g.name))
          g.withMembers([
            for (final m in g.members)
              if (!(cut[g.name]?.contains(m) ?? false) && alive(m)) m,
          ]),
    ];
    final settled =
        next.length == current.length &&
        cut.isEmpty &&
        [
          for (var i = 0; i < next.length; i++)
            next[i].members.length == current[i].members.length,
        ].every((same) => same);
    if (settled) return next;
    current = next.where((g) => g.members.isNotEmpty).toList();
  }
}

PlanRule? _splitRule(String raw) {
  final line = raw.trim();
  if (line.isEmpty || RegExp(r'[\x00-\x1f]').hasMatch(line)) return null;
  final comma = line.indexOf(',');
  if (comma < 0) return null;
  final type = line.substring(0, comma).trim().toUpperCase();
  final rest = line.substring(comma + 1);
  if (type == 'MATCH') {
    final target = rest.split(',').first.trim();
    return target.isEmpty
        ? null
        : PlanRule(type: type, payload: '', target: target);
  }
  final String payload;
  var tail = '';
  if (kLogicRuleTypes.contains(type)) {
    final body = rest.trimLeft();
    if (!body.startsWith('(')) return null;
    var depth = 0;
    int? end;
    for (var i = 0; i < body.length; i++) {
      if (body[i] == '(') depth++;
      if (body[i] == ')' && --depth == 0) {
        end = i;
        break;
      }
    }
    if (end == null) return null;
    payload = body.substring(0, end + 1);
    final after = body.substring(end + 1).trimLeft();
    if (!after.startsWith(',')) return null;
    tail = after.substring(1);
  } else {
    final c = rest.indexOf(',');
    if (c < 0) return null;
    payload = rest.substring(0, c).trim();
    tail = rest.substring(c + 1);
  }
  final parts = tail.split(',').map((e) => e.trim()).toList();
  if (payload.isEmpty || parts.first.isEmpty) return null;
  return PlanRule(
    type: type,
    payload: payload,
    target: parts.first,
    options: [
      for (final o in parts.skip(1))
        if (o.isNotEmpty) o,
    ],
  );
}

List<InlineList> _inlineLists(Object? node) {
  if (node is! Map) return const [];
  final out = <InlineList>[];
  node.forEach((name, spec) {
    if (spec is! Map || '${spec['type']}' != 'inline') return;
    final list = InlineList(
      name: '$name',
      behavior: '${spec['behavior'] ?? 'domain'}',
      payload: [for (final e in (spec['payload'] as List? ?? const [])) '$e'],
    );
    if (list.isValid) out.add(list);
  });
  return out;
}

List<RuleList> clashRuleLists(Object? node) {
  if (node is! Map) return const [];
  final out = <RuleList>[];
  node.forEach((name, spec) {
    if (spec is! Map) return;
    if ('${spec['type']}' != 'http') return;
    final list = RuleList(
      name: '$name',
      url: '${spec['url'] ?? ''}',
      behavior: '${spec['behavior'] ?? ''}',
      format: spec['format'] == null ? 'yaml' : '${spec['format']}',
    );
    if (list.isValid) out.add(list);
  });
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
      out[k] = _deepConvert(
        node is YamlMap ? _asWritten(node.nodes[e.key]) ?? e.value : e.value,
      );
    }
    return out;
  }
  if (node is YamlList || node is List) {
    return [for (final e in (node as List)) _deepConvert(e)];
  }
  return node;
}

String? _asWritten(YamlNode? node) {
  if (node is! YamlScalar || node.value is! num) return null;
  final text = node.span.text;
  return RegExp(r'^0\d+$').hasMatch(text) ? text : null;
}

final _codePointEscape = RegExp(r'\\x\{([0-9A-Fa-f]{1,6})\}');

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
    body = body.replaceAllMapped(_codePointEscape, (m) {
      final cp = int.parse(m[1]!, radix: 16);
      return cp > 0x10FFFF ? m[0]! : RegExp.escape(String.fromCharCode(cp));
    });
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
