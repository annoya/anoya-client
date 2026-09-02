

import 'norm_config.dart';
import 'json_file_store.dart';

/// The direction of a rule set: what happens to traffic no rule names.
///
/// An enum here, a string on the wire: `Routing.mode` mirrors the server's
/// normconfig and stays text, and [wire] is the one place the two meet.
enum RoutingMode {
  /// Everything via VPN; rules are the exceptions.
  full,

  /// Only matching traffic via VPN; the rest connects directly.
  split;

  String get wire => name;

  /// As the summaries print it.
  String get label => this == split ? 'Split' : 'Full tunnel';

  static RoutingMode parse(String? wire) => wire == 'split' ? split : full;
}

/// Which view a rule set opens in. Views over the same rules, not formats —
/// switching never converts or discards anything.
enum RuleEditor {
  /// The service catalog.
  simple,

  /// Raw ordered rules.
  advanced;

  static RuleEditor parse(String? wire) => wire == 'advanced' ? advanced : simple;
}

/// A named, reusable split-tunneling policy. Rule sets are global (device
/// level) and are applied to configurations individually via
/// Profile.ruleSetId; self-hosted profiles with a server-managed policy ignore
/// them. The built-in "Default" set (no rules, full mode) always exists and
/// cannot be deleted.
class RuleSet {
  const RuleSet({
    required this.id,
    required this.name,
    this.mode = RoutingMode.full,
    this.rules = const [],
    this.editor = RuleEditor.simple,
  });

  static const defaultId = 'default';

  final String id;
  final String name;

  final RoutingMode mode;
  final List<RoutingRule> rules;
  final RuleEditor editor;

  bool get isDefault => id == defaultId;

  Routing toRouting() => Routing(mode: mode.wire, rules: rules);

  RuleSet copyWith({String? name, RoutingMode? mode, List<RoutingRule>? rules, RuleEditor? editor}) =>
      RuleSet(
          id: id,
          name: name ?? this.name,
          mode: mode ?? this.mode,
          rules: rules ?? this.rules,
          editor: editor ?? this.editor);

  factory RuleSet.fromJson(Map<String, dynamic> j) => RuleSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Rule set',
        mode: RoutingMode.parse(j['mode'] as String?),
        rules: (j['rules'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => RoutingRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        editor: RuleEditor.parse(j['editor'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.wire,
        'rules': rules.map((r) => r.toJson()).toList(),
        'editor': editor.name,
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
