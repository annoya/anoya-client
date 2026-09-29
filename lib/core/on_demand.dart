import '../l10n/l10n.dart';
import 'json_file_store.dart';

class OnDemandRule {
  const OnDemandRule({
    required this.id,
    this.name = '',
    this.action = OnDemandAction.connect,
    this.interface = OnDemandInterface.any,
    this.ssids = const [],
    this.dnsDomains = const [],
    this.dnsServers = const [],
    this.probeUrl = '',
  });

  final String id;
  final String name;
  final OnDemandAction action;
  final OnDemandInterface interface;
  final List<String> ssids;
  final List<String> dnsDomains;
  final List<String> dnsServers;
  final String probeUrl;

  bool get ssidsApply =>
      interface == OnDemandInterface.wifi || interface == OnDemandInterface.any;

  List<String> get effectiveSsids => ssidsApply ? ssids : const [];

  String get summary {
    final l10n = L10n.current;
    final parts = <String>[interface.label];
    if (effectiveSsids.isNotEmpty) {
      parts.add(l10n.onDemandSummarySsid(effectiveSsids.join(', ')));
    }
    if (dnsDomains.isNotEmpty) {
      parts.add(l10n.onDemandSummaryDomain(dnsDomains.join(', ')));
    }
    if (dnsServers.isNotEmpty) {
      parts.add(l10n.onDemandSummaryDns(dnsServers.join(', ')));
    }
    if (probeUrl.isNotEmpty) parts.add(l10n.onDemandSummaryProbe);
    return parts.join(' · ');
  }

  OnDemandRule copyWith({
    String? name,
    OnDemandAction? action,
    OnDemandInterface? interface,
    List<String>? ssids,
    List<String>? dnsDomains,
    List<String>? dnsServers,
    String? probeUrl,
  }) => OnDemandRule(
    id: id,
    name: name ?? this.name,
    action: action ?? this.action,
    interface: interface ?? this.interface,
    ssids: ssids ?? this.ssids,
    dnsDomains: dnsDomains ?? this.dnsDomains,
    dnsServers: dnsServers ?? this.dnsServers,
    probeUrl: probeUrl ?? this.probeUrl,
  );

  factory OnDemandRule.fromJson(Map<String, dynamic> j) => OnDemandRule(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    action: OnDemandAction.values.firstWhere(
      (a) => a.name == (j['action'] as String? ?? 'connect'),
      orElse: () => OnDemandAction.connect,
    ),
    interface: OnDemandInterface.values.firstWhere(
      (i) => i.name == (j['interface'] as String? ?? 'any'),
      orElse: () => OnDemandInterface.any,
    ),
    ssids: (j['ssids'] as List<dynamic>? ?? []).whereType<String>().toList(),
    dnsDomains: (j['dns_domains'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
    dnsServers: (j['dns_servers'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
    probeUrl: j['probe_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name.isNotEmpty) 'name': name,
    'action': action.name,
    'interface': interface.name,
    if (ssids.isNotEmpty) 'ssids': ssids,
    if (dnsDomains.isNotEmpty) 'dns_domains': dnsDomains,
    if (dnsServers.isNotEmpty) 'dns_servers': dnsServers,
    if (probeUrl.isNotEmpty) 'probe_url': probeUrl,
  };

  Map<String, dynamic> toChannel() => {
    'action': action.name,
    'interface': interface.name,
    'ssids': effectiveSsids,
    'dns_domains': dnsDomains,
    'dns_servers': dnsServers,
    'probe_url': probeUrl,
  };
}

enum OnDemandAction {
  connect,
  disconnect,
  ignore;

  String get label => switch (this) {
    connect => L10n.current.commonConnect,
    disconnect => L10n.current.commonDisconnect,
    ignore => L10n.current.onDemandActionIgnore,
  };
}

enum OnDemandInterface {
  any,
  wifi,
  cellular,
  ethernet;

  String get label => switch (this) {
    any => L10n.current.onDemandInterfaceAny,
    wifi => L10n.current.onDemandInterfaceWifi,
    cellular => L10n.current.onDemandInterfaceCellular,
    ethernet => L10n.current.onDemandInterfaceEthernet,
  };
}

class OnDemandPrefs {
  const OnDemandPrefs({
    this.enabled = false,
    this.paused = false,
    this.disconnectOnSleep = false,
    this.rules = const [],
    this.systemArmed = false,
  });

  final bool enabled;
  final bool paused;
  final bool disconnectOnSleep;
  final List<OnDemandRule> rules;

  final bool systemArmed;

  bool get armed => enabled && !paused && rules.isNotEmpty;

  bool get awaitingFirstConnect => armed && !systemArmed;

  String get statusLabel {
    final l10n = L10n.current;
    if (!enabled) return l10n.commonOff;
    if (paused) return l10n.onDemandStatusPaused;
    if (awaitingFirstConnect) return l10n.onDemandStatusAwaitingFirstConnect;
    return l10n.onDemandStatusOnRules(rules.length);
  }

  OnDemandPrefs copyWith({
    bool? enabled,
    bool? paused,
    bool? disconnectOnSleep,
    List<OnDemandRule>? rules,
    bool? systemArmed,
  }) => OnDemandPrefs(
    enabled: enabled ?? this.enabled,
    paused: paused ?? this.paused,
    disconnectOnSleep: disconnectOnSleep ?? this.disconnectOnSleep,
    rules: rules ?? this.rules,
    systemArmed: systemArmed ?? this.systemArmed,
  );

  factory OnDemandPrefs.fromJson(Map<String, dynamic> j) => OnDemandPrefs(
    enabled: j['enabled'] as bool? ?? false,
    paused: j['paused'] as bool? ?? false,
    disconnectOnSleep: j['disconnect_on_sleep'] as bool? ?? false,
    rules: (j['rules'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => OnDemandRule.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'paused': paused,
    'disconnect_on_sleep': disconnectOnSleep,
    'rules': rules.map((r) => r.toJson()).toList(),
  };
}

class OnDemandStore {
  static final _store = JsonFileStore('on_demand.json');

  static Future<OnDemandPrefs> load() => _store.load(
    (j) => j is Map
        ? OnDemandPrefs.fromJson(Map<String, dynamic>.from(j))
        : const OnDemandPrefs(),
    const OnDemandPrefs(),
  );

  static Future<void> save(OnDemandPrefs prefs) => _store.save(prefs.toJson());
}
