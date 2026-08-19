import 'norm_config.dart';
import 'subscription_info.dart';

/// A configuration source the user has added. The app holds a list of these;
/// each has one or more locations (servers) to connect through.
enum ProfileType {
  /// Self-hosted management server: login (password/SSO), a bundle of
  /// locations, an account (status/quota) and optional managed routing;
  /// refreshed from the server.
  selfhosted,

  /// A subscription URL that returns a list of servers; periodically refreshed.
  subscription,

  /// A single share link (vless://, vmess://…): exactly one server, static.
  link,
}

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
    this.providerInfo,
    this.refreshedAt,
  });

  final String id;
  final ProfileType type;
  final String name; // shown in the profile picker

  /// Cached servers/locations for this source.
  final List<Location> locations;

  /// Source used to refresh: management base URL (selfhosted) or subscription URL.
  final String? serverUrl;
  final String? subscriptionUrl;

  /// Self-hosted only: account status/quota and server-managed routing policy.
  final Account? account;
  final Routing? routing;

  /// Which global rule set applies to this profile (null → Default). Ignored
  /// when the server delivers a managed [routing] policy.
  final String? ruleSetId;

  /// Whether [ruleSetId] applies at all. Routing is opt-in per configuration —
  /// off means no rule set is used and everything goes into the tunnel — because
  /// rule sets are device-global while "should this configuration route around
  /// the tunnel" is a per-configuration decision. A server-managed [routing]
  /// policy ignores this flag: the server owns that policy.
  final bool routingEnabled;

  /// Resolvers this config brought along (a subscription's `dns.nameserver`,
  /// a self-hosted bundle's `dns`). Empty means the app default. Refresh
  /// replaces the whole list, so a source that drops its DNS drops ours too.
  final List<String> dns;

  /// The subscription's panel told us it counts devices (`x-hwid-active`).
  /// Remembered from the last fetch so the settings screen can say that this
  /// installation occupies a slot, without asking the panel again.
  final bool deviceLimitActive;

  /// The panel refused this device on the last fetch: its device limit is
  /// full. The locations below are then whatever it sent instead — usually
  /// placeholders carrying its message.
  final bool deviceLimitReached;

  /// Servers the source offered that this app cannot run, by the name the body
  /// used (`hysteria2`, `wireguard`). Kept so the screen can account for the
  /// difference between what the provider's panel shows and what is here — an
  /// unexplained gap reads as the app losing servers.
  final Map<String, int> unsupportedServers;

  /// What the subscription's panel reported about itself on the last fetch —
  /// plan, message, support link (ADR-005: its words, not a verdict). Null for
  /// the other two domains, which have no panel to speak for them.
  final SubscriptionInfo? providerInfo;

  final DateTime? refreshedAt;

  /// A single-server source (link) shows no location picker.
  bool get isSingleServer => type == ProfileType.link || locations.length <= 1;

  /// Only self-hosted profiles have an account (status, quota, expiry).
  bool get hasAccount => type == ProfileType.selfhosted;

  /// Servers offered, ours and not. Equals [locations].length unless the source
  /// carried protocols this app cannot run.
  int get offeredServers =>
      locations.length + unsupportedServers.values.fold(0, (a, b) => a + b);

  /// Refreshable from a remote source (self-hosted API / subscription URL).
  bool get isRefreshable =>
      type == ProfileType.selfhosted || type == ProfileType.subscription;

  /// The remote-owned half of a profile, replaced wholesale by a refresh:
  /// what the source says, goes — verbatim. In particular `routing: null`
  /// CLEARS a managed policy (the admin detached it) and an empty [dns] drops
  /// ours (ADR-008: a source that drops its DNS drops ours too). copyWith's
  /// null-keeps semantics cannot express either.
  Profile withBundle({
    required List<Location> locations,
    required Account? account,
    required Routing? routing,
    required List<String> dns,
    required DateTime refreshedAt,
    bool deviceLimitActive = false,
    bool deviceLimitReached = false,
    Map<String, int> unsupportedServers = const {},
    SubscriptionInfo? providerInfo,
  }) =>
      Profile(
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
        providerInfo: providerInfo,
        refreshedAt: refreshedAt,
      );

  Profile copyWith({
    String? name,
    List<Location>? locations,
    Account? account,
    Routing? routing,
    String? ruleSetId,
    bool? routingEnabled,
    List<String>? dns,
    DateTime? refreshedAt,
  }) =>
      Profile(
        id: id,
        type: type,
        name: name ?? this.name,
        locations: locations ?? this.locations,
        serverUrl: serverUrl,
        subscriptionUrl: subscriptionUrl,
        account: account ?? this.account,
        routing: routing ?? this.routing,
        ruleSetId: ruleSetId ?? this.ruleSetId,
        routingEnabled: routingEnabled ?? this.routingEnabled,
        dns: dns ?? this.dns,
        deviceLimitActive: deviceLimitActive,
        deviceLimitReached: deviceLimitReached,
        unsupportedServers: unsupportedServers,
        providerInfo: providerInfo,
        refreshedAt: refreshedAt ?? this.refreshedAt,
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
        unsupportedServers: (j['unsupported_servers'] as Map?)
                ?.map((k, v) => MapEntry('$k', v is int ? v : 0)) ??
            const {},
        providerInfo: j['provider_info'] is Map
            ? SubscriptionInfo.fromJson(Map<String, dynamic>.from(j['provider_info'] as Map))
            : null,
        refreshedAt:
            j['refreshed_at'] != null ? DateTime.tryParse(j['refreshed_at'] as String) : null,
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
        if (unsupportedServers.isNotEmpty) 'unsupported_servers': unsupportedServers,
        if (providerInfo != null) 'provider_info': providerInfo!.toJson(),
        if (refreshedAt != null) 'refreshed_at': refreshedAt!.toIso8601String(),
      };
}
