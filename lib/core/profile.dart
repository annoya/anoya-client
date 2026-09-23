import 'amnezia/amnezia_account.dart';
import 'norm_config.dart';
import 'subscription_info.dart';

enum ProfileType { selfhosted, amnezia, subscription, link }

class Profile {
  Profile({
    required this.id,
    required this.type,
    required this.name,
    required this.locations,
    this.serverUrl,
    this.subscriptionUrl,
    this.account,
    this.routing,
    this.ruleSetId,
    this.routingEnabled = false,
    this.dns = const [],
    this.deviceLimitActive = false,
    this.deviceLimitReached = false,
    this.unsupportedServers = const {},
    this.groups = const [],
    this.providerRouting,
    this.providerRoutingSkipped = 0,
    this.providerRoutingEnabled = true,
    this.providerRuleListsEnabled = false,
    this.usedFallback = false,
    this.rendering = '',
    this.renderingProbed = false,
    this.providerRoutingProbed = false,
    this.providerInfo,
    this.refreshedAt,
    this.refreshHours,
    this.amnezia,
  });

  final String id;
  final ProfileType type;
  final String name;

  final List<Location> locations;

  final String? serverUrl;
  final String? subscriptionUrl;

  final Account? account;
  final Routing? routing;

  final String? ruleSetId;

  final bool routingEnabled;

  final List<String> dns;

  final bool deviceLimitActive;

  final bool deviceLimitReached;

  final Map<String, int> unsupportedServers;

  final List<ProxyGroup> groups;

  final Routing? providerRouting;

  final int providerRoutingSkipped;

  final bool providerRoutingEnabled;

  final bool providerRuleListsEnabled;

  final bool usedFallback;

  final String rendering;

  final bool renderingProbed;

  final bool providerRoutingProbed;

  final SubscriptionInfo? providerInfo;

  final DateTime? refreshedAt;

  final int? refreshHours;

  final AmneziaState? amnezia;

  bool get isSingleServer => type == ProfileType.link || locations.length <= 1;

  bool get hasAccount => type == ProfileType.selfhosted;

  int get offeredServers =>
      locations.length + unsupportedServers.values.fold(0, (a, b) => a + b);

  bool get isRefreshable => type != ProfileType.link;

  // Enumerates fields on purpose rather than copying: a new source-owned field
  // must be added here explicitly, or a refresh keeps a stale value.
  Profile withBundle({
    required List<Location> locations,
    required Account? account,
    required Routing? routing,
    required List<String> dns,
    required DateTime refreshedAt,
    bool deviceLimitActive = false,
    bool deviceLimitReached = false,
    Map<String, int> unsupportedServers = const {},
    List<ProxyGroup> groups = const [],
    Routing? providerRouting,
    int providerRoutingSkipped = 0,
    bool providerRoutingProbed = false,
    bool usedFallback = false,
    String rendering = '',
    bool renderingProbed = false,
    SubscriptionInfo? providerInfo,
    AmneziaState? amnezia,
  }) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    serverUrl: serverUrl,
    subscriptionUrl: subscriptionUrl,
    account: account,
    routing: routing,
    ruleSetId: ruleSetId,
    routingEnabled: routingEnabled,
    dns: dns,
    deviceLimitActive: deviceLimitActive,
    deviceLimitReached: deviceLimitReached,
    unsupportedServers: unsupportedServers,
    groups: groups,
    providerRouting: providerRouting,
    providerRoutingSkipped: providerRoutingSkipped,
    providerRoutingEnabled: providerRoutingEnabled,
    providerRuleListsEnabled: providerRuleListsEnabled,
    providerRoutingProbed: providerRoutingProbed,
    providerInfo: providerInfo,
    usedFallback: usedFallback,
    rendering: rendering,
    renderingProbed: renderingProbed,
    refreshedAt: refreshedAt,
    refreshHours: refreshHours,
    amnezia: amnezia ?? this.amnezia,
  );

  Profile copyWith({
    bool? providerRoutingEnabled,
    bool? providerRuleListsEnabled,
    List<Location>? locations,
    String? ruleSetId,
    bool? routingEnabled,
    List<String>? dns,
    DateTime? refreshedAt,
    // Wrapped because null is a real value ("use the source's cadence").
    ({int? value})? refreshHours,
    AmneziaState? amnezia,
  }) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations ?? this.locations,
    serverUrl: serverUrl,
    subscriptionUrl: subscriptionUrl,
    account: account,
    routing: routing,
    ruleSetId: ruleSetId ?? this.ruleSetId,
    routingEnabled: routingEnabled ?? this.routingEnabled,
    dns: dns ?? this.dns,
    deviceLimitActive: deviceLimitActive,
    deviceLimitReached: deviceLimitReached,
    unsupportedServers: unsupportedServers,
    groups: groups,
    providerRouting: providerRouting,
    providerRoutingSkipped: providerRoutingSkipped,
    providerRoutingEnabled:
        providerRoutingEnabled ?? this.providerRoutingEnabled,
    providerRuleListsEnabled:
        providerRuleListsEnabled ?? this.providerRuleListsEnabled,
    providerRoutingProbed: providerRoutingProbed,
    providerInfo: providerInfo,
    usedFallback: usedFallback,
    rendering: rendering,
    renderingProbed: renderingProbed,
    refreshedAt: refreshedAt ?? this.refreshedAt,
    refreshHours: refreshHours == null ? this.refreshHours : refreshHours.value,
    amnezia: amnezia ?? this.amnezia,
  );

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    type: ProfileType.values.byName(j['type'] as String? ?? 'link'),
    name: j['name'] as String? ?? 'Profile',
    locations: (j['locations'] as List<dynamic>? ?? [])
        .map((e) => Location.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    serverUrl: j['server_url'] as String?,
    subscriptionUrl: j['subscription_url'] as String?,
    account: j['account'] is Map
        ? Account.fromJson(Map<String, dynamic>.from(j['account'] as Map))
        : null,
    routing: j['routing'] is Map
        ? Routing.fromJson(Map<String, dynamic>.from(j['routing'] as Map))
        : null,
    ruleSetId: j['rule_set_id'] as String?,
    routingEnabled: j['routing_enabled'] as bool? ?? false,
    dns: (j['dns'] as List<dynamic>? ?? []).whereType<String>().toList(),
    deviceLimitActive: j['device_limit_active'] as bool? ?? false,
    deviceLimitReached: j['device_limit_reached'] as bool? ?? false,
    groups: (j['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ProxyGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    providerRouting: j['provider_routing'] is Map
        ? Routing.fromJson(
            Map<String, dynamic>.from(j['provider_routing'] as Map),
          )
        : null,
    providerRoutingSkipped: j['provider_routing_skipped'] as int? ?? 0,
    providerRoutingEnabled: j['provider_routing_enabled'] as bool? ?? true,
    providerRuleListsEnabled:
        j['provider_rule_lists_enabled'] as bool? ?? false,
    providerRoutingProbed: j['provider_routing_probed'] as bool? ?? false,
    usedFallback: j['used_fallback'] as bool? ?? false,
    rendering: j['rendering'] as String? ?? '',
    renderingProbed: j['rendering_probed'] as bool? ?? false,
    unsupportedServers:
        (j['unsupported_servers'] as Map?)?.map(
          (k, v) => MapEntry('$k', v is int ? v : 0),
        ) ??
        const {},
    providerInfo: j['provider_info'] is Map
        ? SubscriptionInfo.fromJson(
            Map<String, dynamic>.from(j['provider_info'] as Map),
          )
        : null,
    refreshedAt: j['refreshed_at'] != null
        ? DateTime.tryParse(j['refreshed_at'] as String)
        : null,
    refreshHours: j['refresh_hours'] as int?,
    amnezia: j['amnezia'] is Map
        ? AmneziaState.fromJson((j['amnezia'] as Map).cast<String, dynamic>())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'locations': locations.map((l) => l.toJson()).toList(),
    if (serverUrl != null) 'server_url': serverUrl,
    if (subscriptionUrl != null) 'subscription_url': subscriptionUrl,
    if (account != null) 'account': account!.toJson(),
    if (routing != null) 'routing': routing!.toJson(),
    if (ruleSetId != null) 'rule_set_id': ruleSetId,
    if (routingEnabled) 'routing_enabled': true,
    if (dns.isNotEmpty) 'dns': dns,
    if (deviceLimitActive) 'device_limit_active': true,
    if (deviceLimitReached) 'device_limit_reached': true,
    if (unsupportedServers.isNotEmpty)
      'unsupported_servers': unsupportedServers,
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toJson()).toList(),
    if (providerRouting != null) 'provider_routing': providerRouting!.toJson(),
    if (providerRoutingSkipped > 0)
      'provider_routing_skipped': providerRoutingSkipped,
    if (!providerRoutingEnabled) 'provider_routing_enabled': false,
    if (providerRuleListsEnabled) 'provider_rule_lists_enabled': true,
    if (providerRoutingProbed) 'provider_routing_probed': true,
    if (usedFallback) 'used_fallback': true,
    if (rendering.isNotEmpty) 'rendering': rendering,
    if (renderingProbed) 'rendering_probed': true,
    if (providerInfo != null) 'provider_info': providerInfo!.toJson(),
    if (refreshedAt != null) 'refreshed_at': refreshedAt!.toIso8601String(),
    if (refreshHours != null) 'refresh_hours': refreshHours,
    if (amnezia != null) 'amnezia': amnezia!.toJson(),
  };
}

Duration refreshGapFor(Profile p) {
  final hours = p.refreshHours ?? p.providerInfo?.updateInterval;
  if (hours == null || hours <= 0) return kDefaultRefreshGap;
  final asked = Duration(hours: hours);
  return asked < kMinRefreshGap ? kMinRefreshGap : asked;
}

const kDefaultRefreshGap = Duration(hours: 1);

bool isDueForRefresh(Profile p, {DateTime? now}) {
  final at = p.refreshedAt;
  if (at == null) return true;
  return (now ?? DateTime.now()).difference(at) >= refreshGapFor(p);
}

const kMinRefreshGap = Duration(minutes: 5);
