import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';

/// One system on-demand rule (mirrors NEOnDemandRule). Conditions are ANDed;
/// the OS applies the first rule whose conditions all match.
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

  /// An SSID only exists on Wi-Fi: pairing it with a cellular/ethernet rule
  /// would produce a condition the system can never satisfy. The values stay in
  /// the model (so switching back restores them) but are neither shown nor
  /// compiled while another interface is selected.
  bool get ssidsApply =>
      interface == OnDemandInterface.wifi || interface == OnDemandInterface.any;

  List<String> get effectiveSsids => ssidsApply ? ssids : const [];

  /// Condition summary for list rows: "Wi-Fi · SSID corp-net · DNS 10.0.*".
  String get summary {
    final parts = <String>[interface.label];
    if (effectiveSsids.isNotEmpty) parts.add('SSID ${effectiveSsids.join(', ')}');
    if (dnsDomains.isNotEmpty) parts.add('domain ${dnsDomains.join(', ')}');
    if (dnsServers.isNotEmpty) parts.add('DNS ${dnsServers.join(', ')}');
    if (probeUrl.isNotEmpty) parts.add('probe');
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
  }) =>
      OnDemandRule(
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
            orElse: () => OnDemandAction.connect),
        interface: OnDemandInterface.values.firstWhere(
            (i) => i.name == (j['interface'] as String? ?? 'any'),
            orElse: () => OnDemandInterface.any),
        ssids: (j['ssids'] as List<dynamic>? ?? []).cast<String>(),
        dnsDomains: (j['dns_domains'] as List<dynamic>? ?? []).cast<String>(),
        dnsServers: (j['dns_servers'] as List<dynamic>? ?? []).cast<String>(),
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

  /// The dictionary the platform channel sends to Swift (no id/name — the
  /// system rule has neither).
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
  connect('Connect'),
  disconnect('Disconnect'),
  ignore('Ignore');

  const OnDemandAction(this.label);
  final String label;
}

enum OnDemandInterface {
  any('Any network'),
  wifi('Wi-Fi'),
  // iOS matches cellular; macOS has no cellular and matches ethernet instead.
  // The UI shows whichever fits the platform; both serialize distinctly so a
  // synced config stays unambiguous.
  cellular('Mobile'),
  ethernet('Ethernet');

  const OnDemandInterface(this.label);
  final String label;
}

/// On-demand preferences: the user's intent (enabled), the transient pause
/// (manual disconnect while armed), the rules and the sleep flag.
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

  /// What the platform reported back: whether the OS is actually auto-
  /// connecting right now. Not persisted — it lives in the system's own VPN
  /// preferences and is re-read by pushing the prefs.
  final bool systemArmed;

  /// What we ask the system for: intent, not paused, and something to match.
  bool get armed => enabled && !paused && rules.isNotEmpty;

  /// Enabled but the system hasn't taken it yet — happens before the first
  /// successful connect, since there is no tunnel config to auto-start with.
  bool get awaitingFirstConnect => armed && !systemArmed;

  /// Settings row subtitle: Off / Paused / On · N rules.
  String get statusLabel {
    if (!enabled) return 'Off';
    if (paused) return 'Paused';
    if (awaitingFirstConnect) return 'On · after first connect';
    return 'On · ${rules.length} rule${rules.length > 1 ? 's' : ''}';
  }

  OnDemandPrefs copyWith({
    bool? enabled,
    bool? paused,
    bool? disconnectOnSleep,
    List<OnDemandRule>? rules,
    bool? systemArmed,
  }) =>
      OnDemandPrefs(
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
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/on_demand.json');
  }

  static Future<OnDemandPrefs> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const OnDemandPrefs();
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return const OnDemandPrefs();
      return OnDemandPrefs.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      Log.e('on-demand: could not load', '$e');
      return const OnDemandPrefs();
    }
  }

  static Future<void> save(OnDemandPrefs prefs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(prefs.toJson()));
  }
}
