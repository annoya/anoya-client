

import 'norm_config.dart';
import 'json_file_store.dart';

/// A named, reusable split-tunneling policy. Rule sets are global (device
/// level) and are applied to configurations individually via
/// Profile.ruleSetId; self-hosted profiles with a server-managed policy ignore
/// them. The built-in "Default" set (no rules, full mode) always exists and
/// cannot be deleted.
class RuleSet {
  const RuleSet({
    required this.id,
    required this.name,
    this.mode = 'full',
    this.rules = const [],
    this.editor = 'simple',
  });

  static const defaultId = 'default';

  final String id;
  final String name;

  /// "full": everything via VPN, rules are exceptions.
  /// "split": only matching traffic via VPN, the rest is direct.
  final String mode;
  final List<RoutingRule> rules;

  /// Which editor view the set opens in: 'simple' (service catalog) or
  /// 'advanced' (raw ordered rules). Views over the same rules, not formats —
  /// switching never converts or discards anything.
  final String editor;

  bool get isDefault => id == defaultId;

  Routing toRouting() => Routing(mode: mode, rules: rules);

  RuleSet copyWith({String? name, String? mode, List<RoutingRule>? rules, String? editor}) =>
      RuleSet(
          id: id,
          name: name ?? this.name,
          mode: mode ?? this.mode,
          rules: rules ?? this.rules,
          editor: editor ?? this.editor);

  factory RuleSet.fromJson(Map<String, dynamic> j) => RuleSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Rule set',
        mode: j['mode'] as String? ?? 'full',
        rules: (j['rules'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => RoutingRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        editor: j['editor'] as String? ?? 'simple',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode,
        'rules': rules.map((r) => r.toJson()).toList(),
        'editor': editor,
      };
}

/// Persists the global rule sets to rule_sets.json in the app-support
/// directory. Load always yields at least the Default set, in stable order
/// (Default first).
class RuleSetStore {
  static final _store = JsonFileStore('rule_sets.json');

  static const _defaultSet = RuleSet(id: RuleSet.defaultId, name: 'Default');

  static Future<List<RuleSet>> load() async {
    final sets = await _store.load(
        (j) => decodeListLenient(j, 'rule sets', RuleSet.fromJson), <RuleSet>[]);
    if (!sets.any((s) => s.isDefault)) {
      sets.insert(0, _defaultSet);
    } else {
      sets.sort((a, b) => (a.isDefault ? 0 : 1).compareTo(b.isDefault ? 0 : 1));
    }
    return sets;
  }

  static Future<void> save(List<RuleSet> sets) =>
      _store.save(sets.map((s) => s.toJson()).toList());

  static Future<RuleSet> byId(String? id) async {
    final sets = await load();
    return sets.firstWhere((s) => s.id == (id ?? RuleSet.defaultId),
        orElse: () => sets.first);
  }
}
