import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'norm_config.dart';
import 'parsers/base64_text.dart';
import 'rule_set.dart';

const kRuleSetFormatVersion = 1;
const kRuleSetLinkPrefix = 'anoya://ruleset/add/';
const kRuleSetFileSuffix = '.anoya-rules.json';

enum RuleSetSource { anoya, clash, surge, happ }

enum SkipReason { dns, geoUrls, ruleLists, unsupported }

class SkippedPart {
  const SkippedPart(this.reason, {this.count = 0, this.kinds = const []});

  final SkipReason reason;
  final int count;
  final List<String> kinds;
}

class RuleSetImport {
  const RuleSetImport({
    required this.source,
    required this.name,
    required this.mode,
    required this.rules,
    this.skipped = const [],
    this.editor = RuleEditor.advanced,
  });

  final RuleSetSource source;
  final String name;
  final RoutingMode mode;
  final List<RoutingRule> rules;
  final List<SkippedPart> skipped;
  final RuleEditor editor;

  int countOf(String action) => rules.where((r) => r.action == action).length;
}

String encodeRuleSetFile(RuleSet set) =>
    const JsonEncoder.withIndent('  ').convert({
      'anoya_ruleset': kRuleSetFormatVersion,
      'name': set.name,
      'mode': set.mode.wire,
      'editor': set.editor.name,
      'rules': [for (final r in set.rules) r.toJson()],
    });

String encodeRuleSetLink(RuleSet set) {
  final json = utf8.encode(
    jsonEncode({
      'anoya_ruleset': kRuleSetFormatVersion,
      'name': set.name,
      'mode': set.mode.wire,
      'editor': set.editor.name,
      'rules': [for (final r in set.rules) r.toJson()],
    }),
  );
  final packed = base64Url.encode(gzip.encode(json)).replaceAll('=', '');
  return '$kRuleSetLinkPrefix$packed';
}

String uniqueRuleSetName(String name, Iterable<String> taken) {
  final used = {for (final t in taken) t.trim().toLowerCase()};
  if (!used.contains(name.trim().toLowerCase())) return name;
  for (var i = 2; ; i++) {
    final candidate = '$name $i';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}

String ruleSetFileName(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'rule-set' : slug}$kRuleSetFileSuffix';
}

RuleSetImport? parseRuleSetImport(String text, {String fallbackName = ''}) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (t.startsWith(kRuleSetLinkPrefix)) {
    return _fromAnoyaLink(t.substring(kRuleSetLinkPrefix.length));
  }
  final happ = RegExp(
    r'^happ://routing/(?:on)?add/(.+)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (happ != null) {
    final json = tryDecodeLooseBase64(happ[1]!);
    final doc = json == null ? null : _jsonObject(json);
    return doc == null ? null : _fromHapp(doc, fallbackName);
  }
  if (t.startsWith('{')) {
    final doc = _jsonObject(t);
    if (doc == null) return null;
    if (doc.containsKey('anoya_ruleset')) return _fromAnoya(doc, fallbackName);
    if (_happKeys.any(doc.containsKey)) return _fromHapp(doc, fallbackName);
    return null;
  }
  if (RegExp(r'^\s*\[Rule\]\s*$', multiLine: true).hasMatch(t)) {
    return _fromLines(_section(t, 'Rule'), RuleSetSource.surge, fallbackName);
  }
  final yaml = _clashRules(t);
  if (yaml != null) return _fromLines(yaml, RuleSetSource.clash, fallbackName);
  final lines = [
    for (final l in const LineSplitter().convert(t))
      if (l.trim().isNotEmpty && !_isComment(l)) l.trim(),
  ];
  if (lines.isNotEmpty && lines.every(_looksLikeRuleLine)) {
    return _fromLines(lines, RuleSetSource.clash, fallbackName);
  }
  return null;
}

Map<String, dynamic>? _jsonObject(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map<String, dynamic> ? v : null;
  } on FormatException {
    return null;
  }
}

RuleSetImport? _fromAnoyaLink(String packed) {
  try {
    final bytes = gzip.decode(base64Url.decode(base64Url.normalize(packed)));
    final doc = _jsonObject(utf8.decode(bytes));
    return doc == null ? null : _fromAnoya(doc, '');
  } catch (_) {
    return null;
  }
}

RuleSetImport? _fromAnoya(Map<String, dynamic> doc, String fallbackName) {
  final version = doc['anoya_ruleset'];
  if (version is! int || version > kRuleSetFormatVersion) return null;
  final rules = [
    for (final r in (doc['rules'] as List<dynamic>? ?? const []))
      if (r is Map) RoutingRule.fromJson(Map<String, dynamic>.from(r)),
  ];
  return RuleSetImport(
    source: RuleSetSource.anoya,
    name: _nameOr(doc['name'], fallbackName),
    mode: RoutingMode.parse(doc['mode'] as String?),
    rules: rules,
    editor: RuleEditor.parse(doc['editor'] as String?),
  );
}

const _happKeys = {
  'DirectSites',
  'DirectIp',
  'ProxySites',
  'ProxyIp',
  'BlockSites',
  'BlockIp',
  'GlobalProxy',
};

const _happDnsKeys = {
  'RemoteDNSType',
  'RemoteDNSIP',
  'RemoteDNSDomain',
  'DomesticDNSType',
  'DomesticDNSIP',
  'DomesticDNSDomain',
  'DnsHosts',
  'FakeDNS',
};

RuleSetImport _fromHapp(Map<String, dynamic> doc, String fallbackName) {
  final rules = <RoutingRule>[];
  final unsupported = <String>{};
  var dropped = 0;

  List<String> list(String key) => [
    for (final v in (doc[key] as List<dynamic>? ?? const []))
      if (v is String && v.trim().isNotEmpty) v.trim(),
  ];

  void sites(String key, String action) {
    for (final entry in list(key)) {
      final rule = _happSite(entry, action);
      if (rule != null) {
        rules.add(rule);
      } else {
        dropped++;
        unsupported.add(
          entry.contains(':') ? '${entry.split(':').first}:' : entry,
        );
      }
    }
  }

  void ips(String key, String action) {
    for (final entry in list(key)) {
      final rule = _happIp(entry, action);
      if (rule != null) {
        rules.add(rule);
      } else {
        dropped++;
        unsupported.add(entry);
      }
    }
  }

  sites('BlockSites', 'block');
  ips('BlockIp', 'block');
  sites('ProxySites', 'proxy');
  ips('ProxyIp', 'proxy');
  sites('DirectSites', 'direct');
  ips('DirectIp', 'direct');

  bool present(String key) {
    final v = doc[key];
    if (v == null || v == false) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is Iterable) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return true;
  }

  return RuleSetImport(
    source: RuleSetSource.happ,
    name: _nameOr(doc['Name'], fallbackName),
    mode: doc['GlobalProxy'] == false ? RoutingMode.split : RoutingMode.full,
    rules: mergeAdjacentRules(rules),
    skipped: [
      if (_happDnsKeys.any(present)) const SkippedPart(SkipReason.dns),
      if (present('Geoipurl') || present('Geositeurl'))
        const SkippedPart(SkipReason.geoUrls),
      if (dropped > 0)
        SkippedPart(
          SkipReason.unsupported,
          count: dropped,
          kinds: unsupported.take(4).toList(),
        ),
    ],
  );
}

RoutingRule? _happSite(String entry, String action) {
  final colon = entry.indexOf(':');
  final prefix = colon > 0 ? entry.substring(0, colon).toLowerCase() : '';
  final value = colon > 0 ? entry.substring(colon + 1) : entry;
  final type = switch (prefix) {
    '' || 'domain' => 'domain-suffix',
    'full' => 'domain-exact',
    'keyword' => 'domain-keyword',
    'regexp' => 'domain-regex',
    'geosite' => 'geosite',
    _ => null,
  };
  if (type == null) return null;
  final rule = RoutingRule(
    type: type,
    values: [type == 'geosite' ? value.toLowerCase() : value],
    action: action,
  );
  return rule.isValid ? rule : null;
}

RoutingRule? _happIp(String entry, String action) {
  if (entry.toLowerCase().startsWith('geoip:')) {
    final rule = RoutingRule(
      type: 'geoip',
      values: [entry.substring(6).toUpperCase()],
      action: action,
    );
    return rule.isValid ? rule : null;
  }
  final cidr = entry.contains('/')
      ? entry
      : '$entry/${entry.contains(':') ? 128 : 32}';
  final rule = RoutingRule(type: 'ip-cidr', values: [cidr], action: action);
  return rule.isValid ? rule : null;
}

bool _isComment(String line) {
  final l = line.trimLeft();
  return l.startsWith('#') || l.startsWith(';') || l.startsWith('//');
}

List<String> _section(String text, String name) {
  final out = <String>[];
  var inside = false;
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.startsWith('[') && line.endsWith(']')) {
      inside =
          line.substring(1, line.length - 1).toLowerCase() ==
          name.toLowerCase();
      continue;
    }
    if (inside && line.isNotEmpty && !_isComment(line)) out.add(line);
  }
  return out;
}

List<String>? _clashRules(String text) {
  try {
    final doc = loadYaml(text);
    if (doc is! YamlMap) return null;
    final rules = doc['rules'];
    if (rules is! YamlList) return null;
    return [
      for (final r in rules)
        if (r is String) r.trim(),
    ];
  } catch (_) {
    return null;
  }
}

const _clashTypes = {
  'DOMAIN': 'domain-exact',
  'DOMAIN-SUFFIX': 'domain-suffix',
  'DOMAIN-KEYWORD': 'domain-keyword',
  'DOMAIN-REGEX': 'domain-regex',
  'IP-CIDR': 'ip-cidr',
  'IP-CIDR6': 'ip-cidr',
  'GEOIP': 'geoip',
  'GEOSITE': 'geosite',
  'PROCESS-NAME': 'process-name',
};

const _finalTypes = {'MATCH', 'FINAL'};

bool _looksLikeRuleLine(String line) {
  final head = line.split(',').first.trim().toUpperCase();
  return _clashTypes.containsKey(head) ||
      _finalTypes.contains(head) ||
      RegExp(r'^[A-Z][A-Z0-9-]+$').hasMatch(head) && line.contains(',');
}

String _action(String policy) {
  final p = policy.trim().toUpperCase();
  if (p == 'DIRECT') return 'direct';
  if (p.startsWith('REJECT')) return 'block';
  return 'proxy';
}

RuleSetImport? _fromLines(
  List<String> lines,
  RuleSetSource source,
  String fallbackName,
) {
  final rules = <RoutingRule>[];
  final unsupported = <String>{};
  var dropped = 0;
  var lists = 0;
  var known = 0;
  var mode = RoutingMode.split;

  for (final line in lines) {
    final parts = [for (final p in line.split(',')) p.trim()];
    final head = parts.first.toUpperCase();
    if (_finalTypes.contains(head)) {
      known++;
      if (parts.length > 1) {
        mode = _action(parts[1]) == 'direct'
            ? RoutingMode.split
            : RoutingMode.full;
      }
      continue;
    }
    if (head == 'RULE-SET' || head == 'DOMAIN-SET') {
      known++;
      lists++;
      continue;
    }
    final type = _clashTypes[head];
    if (type != null) known++;
    if (type == null || parts.length < 3) {
      dropped++;
      unsupported.add(head);
      continue;
    }
    final value = switch (type) {
      'geoip' => parts[1].toUpperCase(),
      'geosite' => parts[1].toLowerCase(),
      _ => parts[1],
    };
    final rule = RoutingRule(
      type: type,
      values: [value],
      action: _action(parts[2]),
      noResolve:
          type == 'ip-cidr' &&
          parts.skip(3).any((o) => o.toLowerCase() == 'no-resolve'),
    );
    if (rule.isValid) {
      rules.add(rule);
    } else {
      dropped++;
      unsupported.add(head);
    }
  }

  if (known == 0) return null;
  return RuleSetImport(
    source: source,
    name: _nameOr(null, fallbackName),
    mode: mode,
    rules: mergeAdjacentRules(rules),
    skipped: [
      if (lists > 0) SkippedPart(SkipReason.ruleLists, count: lists),
      if (dropped > 0)
        SkippedPart(
          SkipReason.unsupported,
          count: dropped,
          kinds: unsupported.take(4).toList(),
        ),
    ],
  );
}

List<RoutingRule> mergeAdjacentRules(List<RoutingRule> rules) {
  final out = <RoutingRule>[];
  for (final r in rules) {
    final last = out.lastOrNull;
    if (last != null &&
        last.type == r.type &&
        last.action == r.action &&
        last.noResolve == r.noResolve &&
        !r.needsRuleList) {
      out.last = last.copyWith(values: {...last.values, ...r.values}.toList());
    } else {
      out.add(r);
    }
  }
  return out;
}

String _nameOr(Object? name, String fallback) {
  final n = name is String ? name.trim() : '';
  return n.isNotEmpty ? n : fallback;
}
