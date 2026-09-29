import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';

class ProviderRouting {
  const ProviderRouting({required this.routing, this.skipped = 0});

  final Routing routing;

  final int skipped;

  bool get isEmpty => routing.rules.isEmpty;
}

ProviderRouting? parseXrayRouting(String body) {
  try {
    final decoded = jsonDecode(body);
    final cfg = decoded is List
        ? (decoded.isEmpty ? null : decoded.first)
        : decoded;
    if (cfg is! Map) return null;
    final routing = cfg['routing'];
    if (routing is! Map) return null;
    final raw = routing['rules'];
    if (raw is! List) return null;

    final rules = <RoutingRule>[];
    var skipped = 0;
    String? catchAll;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final action = _actionForTag(entry['outboundTag']);

      final hasMatcher = entry['domain'] != null || entry['ip'] != null;
      if (!hasMatcher) {
        if (entry['inboundTag'] != null ||
            entry['port'] != null ||
            entry['protocol'] != null) {
          continue;
        }
        if (action != null) catchAll = action;
        continue;
      }
      if (action == null) {
        skipped++;
        continue;
      }

      for (final d in (entry['domain'] as List? ?? const [])) {
        final rule = _domainRule('$d', action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
      for (final ip in (entry['ip'] as List? ?? const [])) {
        final rule = _ipRule('$ip', action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
    }

    if (rules.isEmpty) return null;
    final mode = catchAll == 'direct' ? 'split' : 'full';
    return ProviderRouting(
      routing: Routing(mode: mode, rules: rules),
      skipped: skipped,
    );
  } catch (e) {
    Log.e('provider routing: unreadable xray routing', '$e');
    return null;
  }
}

ProviderRouting? parseHappRouting(String header) {
  try {
    final payload = header.trim().split('/').last;
    final json = jsonDecode(decodeLooseBase64(payload));
    if (json is! Map) return null;

    final rules = <RoutingRule>[];
    var skipped = 0;
    void addAll(String? key, String type, String action) {
      for (final v in (json[key] as List? ?? const [])) {
        final s = '$v'.trim();
        if (s.isEmpty) continue;
        final rule = type == 'domain'
            ? _domainRule(s, action)
            : _ipRule(s, action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
    }

    addAll('ProxySites', 'domain', 'proxy');
    addAll('ProxyIp', 'ip', 'proxy');
    addAll('DirectSites', 'domain', 'direct');
    addAll('DirectIp', 'ip', 'direct');
    addAll('BlockSites', 'domain', 'block');
    addAll('BlockIp', 'ip', 'block');

    final global = '${json['GlobalProxy']}'.toLowerCase() == 'true';
    final mode = global ? 'full' : 'split';
    if (rules.isEmpty) {
      return null;
    }
    return ProviderRouting(
      routing: Routing(mode: mode, rules: rules),
      skipped: skipped,
    );
  } catch (e) {
    Log.e('provider routing: unreadable happ routing', '$e');
    return null;
  }
}

ProviderRouting? parseClashRouting(String body) {
  final YamlMap doc;
  try {
    final parsed = loadYaml(body);
    if (parsed is! YamlMap) return null;
    doc = parsed;
  } catch (e) {
    Log.e('provider routing: unreadable clash body', '$e');
    return null;
  }
  final rules = (doc['rules'] as YamlList?)?.map((e) => '$e').toList();
  if (rules == null || rules.isEmpty) return null;
  return parseClashRules(rules, lists: _clashRuleLists(doc['rule-providers']));
}

List<RuleList> _clashRuleLists(Object? node) {
  if (node is! YamlMap) return const [];
  final out = <RuleList>[];
  node.forEach((name, spec) {
    if (spec is! YamlMap) return;
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

ProviderRouting? parseClashRules(
  List<String> lines, {
  List<RuleList> lists = const [],
}) {
  final rules = <RoutingRule>[];
  var skipped = 0;
  String? catchAll;
  for (final line in lines) {
    final parts = line.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) continue;
    final type = parts[0].toUpperCase();
    if (type == 'MATCH') {
      catchAll = _actionForTag(parts[1]);
      continue;
    }
    final ourType = switch (type) {
      'DOMAIN-SUFFIX' => 'domain-suffix',
      'DOMAIN-KEYWORD' => 'domain-keyword',
      'DOMAIN' => 'domain-exact',
      'IP-CIDR' || 'IP-CIDR6' => 'ip-cidr',
      'GEOIP' => 'geoip',
      'GEOSITE' => 'geosite',
      'DOMAIN-REGEX' => 'domain-regex',
      'PROCESS-NAME' => 'process-name',
      'RULE-SET' => 'rule-list',
      _ => null,
    };
    final action = parts.length >= 3 ? _actionForTag(parts[2]) : null;
    if (ourType == null || action == null) {
      skipped++;
      continue;
    }
    final rule = RoutingRule(
      type: ourType,
      value: parts[1],
      action: action,
      noResolve: parts.contains('no-resolve'),
    );
    if (rule.isValid) {
      rules.add(rule);
    } else {
      skipped++;
    }
  }
  if (rules.isEmpty) return null;
  final named = <RuleList>[];
  final usable = <RoutingRule>[];
  for (final r in rules) {
    if (r.type != 'rule-list') {
      usable.add(r);
      continue;
    }
    final list = lists.where((l) => l.name == r.value).firstOrNull;
    if (list == null) {
      skipped++;
      continue;
    }
    if (!named.contains(list)) named.add(list);
    usable.add(r);
  }
  if (usable.isEmpty) return null;
  final mode = catchAll == 'direct' ? 'split' : 'full';
  return ProviderRouting(
    routing: Routing(mode: mode, rules: usable, lists: named),
    skipped: skipped,
  );
}

String? _actionForTag(Object? tag) {
  final t = '${tag ?? ''}'.toLowerCase();
  if (t.isEmpty) return null;
  if (t.contains('block') || t.contains('reject') || t.contains('blackhole')) {
    return 'block';
  }
  if (t.contains('direct') || t.contains('bypass')) return 'direct';
  if (t.contains('dns')) return null;
  return 'proxy';
}

RoutingRule? _domainRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, value: value, action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('domain:')) return make('domain-suffix', v.substring(7));
  if (v.startsWith('full:')) return make('domain-exact', v.substring(5));
  if (v.startsWith('keyword:')) return make('domain-keyword', v.substring(8));
  if (v.startsWith('geosite:')) return make('geosite', v.substring(8));
  if (v.startsWith('regexp:')) return make('domain-regex', v.substring(7));
  if (v.startsWith('ext:')) return null;
  return make('domain-keyword', v);
}

RoutingRule? _ipRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, value: value, action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('geoip:')) return make('geoip', v.substring(6));
  if (v.startsWith('ext:')) return null;
  if (!v.contains('/') && !v.contains(':')) return make('ip-cidr', '$v/32');
  return make('ip-cidr', v);
}
