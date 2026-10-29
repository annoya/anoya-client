import 'norm_config.dart';

class PlanGroup {
  const PlanGroup({
    required this.name,
    required this.type,
    required this.members,
    this.testUrl = '',
    this.intervalSeconds = 0,
    this.tolerance = 0,
    this.strategy = '',
  });

  final String name;

  final String type;

  final List<String> members;

  final String testUrl;

  final int intervalSeconds;

  final int tolerance;

  final String strategy;

  static const types = [
    'select',
    'url-test',
    'fallback',
    'load-balance',
    'relay',
  ];

  bool get isSelect => type == 'select';

  bool get isChoosable => isSelect && members.length > 1;

  ProxyGroup get engineGroup => ProxyGroup(
    name: name,
    type: type,
    members: members,
    testUrl: testUrl,
    intervalSeconds: intervalSeconds,
    tolerance: tolerance,
    strategy: strategy,
  );

  PlanGroup withMembers(List<String> members) => PlanGroup(
    name: name,
    type: type,
    members: members,
    testUrl: testUrl,
    intervalSeconds: intervalSeconds,
    tolerance: tolerance,
    strategy: strategy,
  );

  factory PlanGroup.fromJson(Map<String, dynamic> json) => PlanGroup(
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    members: (json['members'] as List? ?? const []).map((e) => '$e').toList(),
    testUrl: json['url'] as String? ?? '',
    intervalSeconds: (json['interval'] as num?)?.toInt() ?? 0,
    tolerance: (json['tolerance'] as num?)?.toInt() ?? 0,
    strategy: json['strategy'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'members': members,
    if (testUrl.isNotEmpty) 'url': testUrl,
    if (intervalSeconds > 0) 'interval': intervalSeconds,
    if (tolerance > 0) 'tolerance': tolerance,
    if (strategy.isNotEmpty) 'strategy': strategy,
  };
}

class PlanRule {
  const PlanRule({
    required this.type,
    required this.payload,
    required this.target,
    this.options = const [],
  });

  final String type;

  final String payload;

  final String target;

  final List<String> options;

  bool get isCatchAll => type == 'MATCH';

  Set<String> get lists => {
    if (type == 'RULE-SET') payload,
    if (kLogicRuleTypes.contains(type))
      for (final m in nestedListPattern.allMatches(payload)) m[1]!.trim(),
  };

  Set<String> get types => {
    type,
    if (kLogicRuleTypes.contains(type))
      for (final m in _nestedType.allMatches(payload)) m[1]!,
  };

  bool get needsGeoData => types.contains('GEOIP') || types.contains('GEOSITE');

  bool get needsProcess => types.any((t) => t.startsWith('PROCESS-'));

  factory PlanRule.fromJson(Map<String, dynamic> json) => PlanRule(
    type: json['type'] as String? ?? '',
    payload: json['payload'] as String? ?? '',
    target: json['target'] as String? ?? '',
    options: (json['options'] as List? ?? const []).map((e) => '$e').toList(),
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'payload': payload,
    'target': target,
    if (options.isNotEmpty) 'options': options,
  };
}

final _nestedType = RegExp(r'\(\s*([A-Z0-9-]+)\s*,');

final nestedListPattern = RegExp(r'\(\s*RULE-SET\s*,\s*([^,()]+)');

class InlineList {
  const InlineList({
    required this.name,
    required this.behavior,
    required this.payload,
  });

  final String name;

  final String behavior;

  final List<String> payload;

  static final _nameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

  bool get isValid =>
      _nameRe.hasMatch(name) &&
      RuleList.behaviors.contains(behavior) &&
      payload.isNotEmpty &&
      payload.every((e) => !RegExp(r'[\x00-\x1f]').hasMatch(e));

  factory InlineList.fromJson(Map<String, dynamic> json) => InlineList(
    name: json['name'] as String? ?? '',
    behavior: json['behavior'] as String? ?? '',
    payload: (json['payload'] as List? ?? const []).map((e) => '$e').toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'behavior': behavior,
    'payload': payload,
  };
}

const kLogicRuleTypes = {'AND', 'OR', 'NOT'};

const kPlanRuleTypes = {
  'DOMAIN',
  'DOMAIN-SUFFIX',
  'DOMAIN-KEYWORD',
  'DOMAIN-REGEX',
  'DOMAIN-WILDCARD',
  'GEOSITE',
  'GEOIP',
  'IP-CIDR',
  'IP-CIDR6',
  'IP-SUFFIX',
  'IP-ASN',
  'DST-PORT',
  'NETWORK',
  'PROCESS-NAME',
  'PROCESS-PATH',
  'PROCESS-NAME-REGEX',
  'PROCESS-PATH-REGEX',
  'RULE-SET',
  'MATCH',
  ...kLogicRuleTypes,
};

const kPlanRuleOptions = {'no-resolve'};

class ClashPlan {
  const ClashPlan({
    required this.groups,
    required this.rules,
    this.lists = const [],
    this.inline = const [],
    this.dialers = const {},
    this.skipped = 0,
  });

  final List<PlanGroup> groups;

  final Map<String, String> dialers;

  final List<PlanRule> rules;

  final List<RuleList> lists;

  final List<InlineList> inline;

  final int skipped;

  static const direct = 'DIRECT';
  static const block = 'REJECT';
  static const _groupPrefix = '@';

  static String groupRef(String name) => '$_groupPrefix$name';

  static String? groupNameOf(String ref) =>
      ref.startsWith(_groupPrefix) ? ref.substring(_groupPrefix.length) : null;

  PlanGroup? group(String name) =>
      groups.where((g) => g.name == name).firstOrNull;

  PlanGroup? groupOf(String ref) {
    final name = groupNameOf(ref);
    return name == null ? null : group(name);
  }

  String get catchAll =>
      rules.where((r) => r.isCatchAll).firstOrNull?.target ?? direct;

  List<PlanGroup> get ruleGroups {
    final out = <PlanGroup>[];
    for (final r in rules) {
      final g = groupOf(r.target);
      if (g != null && !out.contains(g)) out.add(g);
    }
    return out;
  }

  factory ClashPlan.fromJson(Map<String, dynamic> json) => ClashPlan(
    groups: (json['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PlanGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    rules: (json['rules'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PlanRule.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    lists: (json['lists'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RuleList.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    inline: (json['inline'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => InlineList.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    dialers:
        (json['dialers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
        const {},
    skipped: json['skipped'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'groups': groups.map((g) => g.toJson()).toList(),
    'rules': rules.map((r) => r.toJson()).toList(),
    if (lists.isNotEmpty) 'lists': lists.map((l) => l.toJson()).toList(),
    if (inline.isNotEmpty) 'inline': inline.map((l) => l.toJson()).toList(),
    if (dialers.isNotEmpty) 'dialers': dialers,
    if (skipped > 0) 'skipped': skipped,
  };
}

String effectiveMember(PlanGroup group, Map<String, String> choices) {
  final chosen = choices[group.name];
  if (chosen != null && group.members.contains(chosen)) return chosen;
  return group.members.first;
}

String resolvePlanRef(String ref, ClashPlan plan, Map<String, String> choices) {
  final seen = <String>{};
  var current = ref;
  while (true) {
    final g = plan.groupOf(current);
    if (g == null || !g.isSelect || !seen.add(g.name)) return current;
    current = effectiveMember(g, choices);
  }
}
