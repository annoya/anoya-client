// Dart mirror of the management service's normalized client config
// (shared/normconfig in Go). Core-agnostic: a Location's proxy is an open map
// keyed by "type", which the active VpnCore knows how to translate.

class NormConfig {
  NormConfig(
      {required this.version,
      required this.account,
      required this.locations,
      this.routing,
      this.dns = const []});

  final int version;
  final Account account;
  final List<Location> locations;

  /// Split-tunneling policy. Set by the server ("managed") or filled in from
  /// the device-local rules before the config is handed to the core.
  final Routing? routing;

  /// Resolvers the config ships with (mihomo nameserver syntax). Empty means
  /// the app default; the tunnel config carries them, so switching configs
  /// switches DNS with no extra plumbing.
  final List<String> dns;

  factory NormConfig.fromJson(Map<String, dynamic> json) {
    final locs = (json['locations'] as List<dynamic>? ?? [])
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
    final routingJson = json['routing'];
    return NormConfig(
      version: json['version'] as int? ?? 1,
      account: Account.fromJson(json['account'] as Map<String, dynamic>? ?? {}),
      locations: locs,
      routing: routingJson is Map ? Routing.fromJson(Map<String, dynamic>.from(routingJson)) : null,
      dns: (json['dns'] as List<dynamic>? ?? []).whereType<String>().toList(),
    );
  }

  NormConfig withRouting(Routing? routing) => NormConfig(
      version: version, account: account, locations: locations, routing: routing, dns: dns);
}

/// Split-tunneling policy: mode + ordered rules, first match wins (the same
/// model the management service stores — see shared/normconfig in Go).
class Routing {
  const Routing({required this.mode, required this.rules});

  /// "full": everything via VPN, rules are exceptions.
  /// "split": only matching traffic via VPN, the rest is direct.
  final String mode;
  final List<RoutingRule> rules;

  factory Routing.fromJson(Map<String, dynamic> json) => Routing(
        mode: json['mode'] as String? ?? 'full',
        rules: (json['rules'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => RoutingRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'mode': mode, 'rules': rules.map((r) => r.toJson()).toList()};
}

class RoutingRule {
  const RoutingRule({
    required this.type,
    required this.value,
    required this.action,
    this.noResolve = false,
  });

  final String type; // domain-suffix|domain-keyword|domain-exact|ip-cidr|process-name|geoip|geosite
  final String value;
  final String action; // proxy|direct|block

  /// geoip only: match plain-IP connections without resolving domains first.
  /// Client-side extension — server-managed rules never carry it.
  final bool noResolve;

  factory RoutingRule.fromJson(Map<String, dynamic> json) => RoutingRule(
        type: json['type'] as String? ?? '',
        value: json['value'] as String? ?? '',
        action: json['action'] as String? ?? '',
        noResolve: json['no_resolve'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'action': action,
        if (noResolve) 'no_resolve': true,
      };

  static const types = [
    'domain-suffix', 'domain-keyword', 'domain-exact', 'ip-cidr', 'process-name',
    'geoip', 'geosite',
  ];
  static const actions = ['proxy', 'direct', 'block'];

  static final _domainRe = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');
  static final _cidrRe = RegExp(r'^[0-9a-fA-F:.]+/\d{1,3}$');
  static final _processRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$');
  static final _geoipRe = RegExp(r'^[A-Za-z]{2}$'); // ISO 3166-1 alpha-2
  static final _geositeRe = RegExp(r'^[a-z0-9][a-z0-9@.!-]*$'); // geosite category

  /// Whether this rule needs the local GeoIP/GeoSite databases to work.
  bool get needsGeoData => type == 'geoip' || type == 'geosite';

  /// Mirrors the server-side validation. Rule values end up interpolated into
  /// the core's config text, so invalid ones must never pass (also applied at
  /// render time as defense in depth).
  bool get isValid {
    if (!actions.contains(action)) return false;
    switch (type) {
      case 'domain-suffix':
      case 'domain-keyword':
      case 'domain-exact':
        return _domainRe.hasMatch(value);
      case 'ip-cidr':
        return _cidrRe.hasMatch(value);
      case 'process-name':
        return _processRe.hasMatch(value);
      case 'geoip':
        return _geoipRe.hasMatch(value);
      case 'geosite':
        return _geositeRe.hasMatch(value);
      default:
        return false;
    }
  }
}

class Account {
  Account({
    required this.displayName,
    required this.status,
    this.expiresAt,
    this.usedBytes = 0,
    this.dataLimit = 0,
  });

  final String displayName;
  final String status; // active | expired | limited | on_hold | deactivated
  final DateTime? expiresAt;
  final int usedBytes;
  final int dataLimit; // 0 = unlimited

  bool get isActive => status == 'active';

  /// on_hold users may connect — their expiry starts on first use.
  bool get canConnect => status == 'active' || status == 'on_hold';

  factory Account.fromJson(Map<String, dynamic> json) {
    final exp = json['expires_at'] as String?;
    return Account(
      displayName: json['display_name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      expiresAt: exp != null ? DateTime.tryParse(exp) : null,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      dataLimit: (json['data_limit'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'status': status,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        'used_bytes': usedBytes,
        'data_limit': dataLimit,
      };
}

class Location {
  Location({required this.id, required this.label, required this.proxy});

  final String id;
  final String label;
  final Map<String, dynamic> proxy;

  String get proxyType => proxy['type'] as String? ?? '';

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        proxy: Map<String, dynamic>.from(json['proxy'] as Map? ?? {}),
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'proxy': proxy};
}
