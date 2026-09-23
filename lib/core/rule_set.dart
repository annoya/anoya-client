import '../l10n/l10n.dart';
import 'norm_config.dart';
import 'json_file_store.dart';

enum RoutingMode {
  full,

  split;

  String get wire => name;

  String get label => this == split
      ? L10n.current.ruleSetModeSplit
      : L10n.current.ruleSetModeFull;

  static RoutingMode parse(String? wire) => wire == 'split' ? split : full;
}

enum RuleEditor {
  simple,

  advanced;

  static RuleEditor parse(String? wire) =>
      wire == 'advanced' ? advanced : simple;
}

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

  RuleSet copyWith({
    String? name,
    RoutingMode? mode,
    List<RoutingRule>? rules,
    RuleEditor? editor,
  }) => RuleSet(
    id: id,
    name: name ?? this.name,
    mode: mode ?? this.mode,
    rules: rules ?? this.rules,
    editor: editor ?? this.editor,
  );

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

class RuleSetStore {
  static final _store = JsonFileStore('rule_sets.json');

  static const _defaultSet = RuleSet(id: RuleSet.defaultId, name: 'Default');

  static Future<List<RuleSet>> load() async {
    final sets = await _store.load(
      (j) => decodeListLenient(j, 'rule sets', RuleSet.fromJson),
      <RuleSet>[],
    );
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
    return sets.firstWhere(
      (s) => s.id == (id ?? RuleSet.defaultId),
      orElse: () => sets.first,
    );
  }
}
