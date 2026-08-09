import 'norm_config.dart';

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

  final DateTime? refreshedAt;

  /// A single-server source (link) shows no location picker.
  bool get isSingleServer => type == ProfileType.link || locations.length <= 1;

  /// Only self-hosted profiles have an account (status, quota, expiry).
  bool get hasAccount => type == ProfileType.selfhosted;

  /// Refreshable from a remote source (self-hosted API / subscription URL).
  bool get isRefreshable =>
      type == ProfileType.selfhosted || type == ProfileType.subscription;

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
        if (refreshedAt != null) 'refreshed_at': refreshedAt!.toIso8601String(),
      };
}
