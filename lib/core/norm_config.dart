// Dart mirror of the management service's normalized client config
// (shared/normconfig in Go). Core-agnostic: a Location's proxy is an open map
// keyed by "type", which the active VpnCore knows how to translate.

class NormConfig {
  NormConfig(
      {required this.version,
      required this.account,
      required this.locations,
      this.groups = const [],
      this.routing,
      this.dns = const []});

  final int version;
  final Account account;
  final List<Location> locations;

  /// Groups a subscription offered, whose member the engine picks.
  final List<ProxyGroup> groups;

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
}

/// Split-tunneling policy: mode + ordered rules, first match wins (the same
/// model the management service stores — see shared/normconfig in Go).
class Routing {
  const Routing({required this.mode, required this.rules, this.lists = const []});

  /// "full": everything via VPN, rules are exceptions.
  /// "split": only matching traffic via VPN, the rest is direct.
  final String mode;
  final List<RoutingRule> rules;

  /// Definitions for the `rule-list` rules above: a rule names a list, this
  /// says where that list comes from. Only a third party's policy carries
  /// these — the management service expresses everything as rules, and a
  /// device-local set has no external files.
  final List<RuleList> lists;

  RuleList? listNamed(String name) =>
      lists.where((l) => l.name == name).firstOrNull;

  factory Routing.fromJson(Map<String, dynamic> json) => Routing(
        mode: json['mode'] as String? ?? 'full',
        rules: (json['rules'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => RoutingRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lists: (json['lists'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => RuleList.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'rules': rules.map((r) => r.toJson()).toList(),
        if (lists.isNotEmpty) 'lists': lists.map((l) => l.toJson()).toList(),
      };
}

/// A set of servers whose member the **engine** picks, not the user.
///
/// Comes from a subscription's `proxy-groups`. Only the types where the choice
/// is the engine's are carried: `url-test` (lowest latency), `fallback` (first
/// that answers), `load-balance` and `relay` (a chain). A `select` group means
/// "let a human choose", which is what our own server picker already is —
/// carrying it would put a picker inside a picker.
class ProxyGroup {
  const ProxyGroup({
    required this.name,
    required this.type,
    required this.members,
    this.testUrl = '',
    this.intervalSeconds = 0,
    this.tolerance = 0,
    this.strategy = '',
  });

  /// The provider's own name, shown to the user. Never interpolated into the
  /// engine config — the renderer generates safe names for that.
  final String name;

  /// `url-test` | `fallback` | `load-balance` | `relay`.
  final String type;

  /// Ids of the [Location]s in this group, in the provider's order. Order is
  /// meaning, not decoration: `fallback` takes the first that answers.
  final List<String> members;

  /// What the engine fetches to measure a member. The provider's choice; a
  /// test against a URL nobody uses measures nothing useful.
  final String testUrl;

  /// How often the provider wants members re-measured.
  final int intervalSeconds;

  /// Milliseconds a new leader must beat the current one by before the engine
  /// switches. Without it two servers a few ms apart would trade the traffic
  /// on every round.
  final int tolerance;

  /// `load-balance` only: how the engine spreads traffic across members.
  /// Empty means the engine's own default (consistent-hashing).
  ///
  /// Carried and validated rather than passed through: mihomo rejects an
  /// unknown strategy, and it rejects it while applying the config — which
  /// would take the whole tunnel down over one field a provider mistyped.
  final String strategy;

  static const types = ['url-test', 'fallback', 'load-balance', 'relay'];
  static const strategies = ['round-robin', 'consistent-hashing', 'sticky-sessions'];

  /// A group id is a location id in the picker's eyes, so both can share the
  /// one selection the app already has.
  String get id => 'group:$name';

  static bool isGroupId(String id) => id.startsWith('group:');

  bool get isValid =>
      name.isNotEmpty && types.contains(type) && members.isNotEmpty;

  /// What the row says the group does. The type name from someone else's YAML
  /// tells the user nothing; this is the same fact in words they can act on.
  String describe(int memberCount) => switch (type) {
        'url-test' => 'Lowest latency of $memberCount',
        'fallback' => 'First of $memberCount that answers · in their order',
        'load-balance' => 'Spread across $memberCount',
        'relay' => 'Chain of $memberCount',
        _ => '$memberCount servers',
      };

  factory ProxyGroup.fromJson(Map<String, dynamic> json) => ProxyGroup(
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

/// A file of rules someone else maintains, named by a `rule-list` rule.
///
/// The engine can fetch these itself, and deliberately is not allowed to: its
/// initial fetch happens inside config apply, under a wait group with a 20 s
/// timeout per file (mihomo `hub/executor/executor.go`, `loadProvider`), which
/// would stall a connect exactly the way the geo databases did — and a fetch
/// that fails there is only logged, leaving a rule that silently matches
/// nothing. The app downloads them instead and hands the engine a local file.
class RuleList {
  const RuleList({
    required this.name,
    required this.url,
    required this.behavior,
    this.format = 'yaml',
    this.intervalSeconds = 0,
  });

  final String name;
  final String url;

  /// What the file contains: `domain`, `ipcidr` or `classical` (mixed rule
  /// lines). Passed through to the engine, which does the parsing.
  final String behavior;

  /// `yaml`, `text` or `mrs` (mihomo's binary rule-set format).
  final String format;

  /// How often the publisher wants it re-read. Advisory: the app refreshes on
  /// its own schedule, and a source asking for every 60 s does not get it.
  final int intervalSeconds;

  static const behaviors = ['domain', 'ipcidr', 'classical'];
  static const formats = ['yaml', 'text', 'mrs'];
  static final _nameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

  /// A list is only usable if we can name it in YAML, fetch it over TLS and
  /// hand the engine a behavior/format it understands. Everything here ends up
  /// interpolated into the engine config, so nothing unvalidated may pass.
  bool get isValid {
    if (!_nameRe.hasMatch(name)) return false;
    if (!behaviors.contains(behavior) || !formats.contains(format)) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  factory RuleList.fromJson(Map<String, dynamic> json) => RuleList(
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        behavior: json['behavior'] as String? ?? '',
        format: json['format'] as String? ?? 'yaml',
        intervalSeconds: (json['interval'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'behavior': behavior,
        'format': format,
        if (intervalSeconds > 0) 'interval': intervalSeconds,
      };
}

class RoutingRule {
  const RoutingRule({
    required this.type,
    required this.value,
    required this.action,
    this.noResolve = false,
  });

  // domain-suffix|domain-keyword|domain-exact|domain-regex|ip-cidr|
  // process-name|geoip|geosite|rule-list
  final String type;
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
    'domain-suffix', 'domain-keyword', 'domain-exact', 'domain-regex', 'ip-cidr',
    'process-name', 'geoip', 'geosite', 'rule-list',
  ];
  static const actions = ['proxy', 'direct', 'block'];

  static final _domainRe = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');
  static final _cidrRe = RegExp(r'^[0-9a-fA-F:.]+/\d{1,3}$');
  static final _processRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$');
  static final _geoipRe = RegExp(r'^[A-Za-z]{2}$'); // ISO 3166-1 alpha-2
  static final _geositeRe = RegExp(r'^[a-z0-9][a-z0-9@.!-]*$'); // geosite category
  static final _listRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  // A rule line is comma-separated and unquoted in the engine's own parser, so
  // a pattern containing a comma cannot be expressed at all — and `#` would
  // start a YAML comment. Both are rejected rather than escaped: there is no
  // escaping that mihomo's splitter would honour.
  static final _regexRe = RegExp(r'^[^,#\r\n]{1,256}$');

  /// Whether this rule needs the local GeoIP/GeoSite databases to work.
  bool get needsGeoData => type == 'geoip' || type == 'geosite';

  /// Whether this rule needs a downloaded [RuleList] to work.
  bool get needsRuleList => type == 'rule-list';

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
      case 'domain-regex':
        if (!_regexRe.hasMatch(value)) return false;
        // A pattern the engine cannot compile is a rule that matches nothing,
        // which reads as "not routed" instead of "broken".
        try {
          RegExp(value);
          return true;
        } on FormatException {
          return false;
        }
      case 'rule-list':
        return _listRe.hasMatch(value);
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
  Location({
    required this.id,
    required this.label,
    required this.proxy,
    this.description = '',
  });

  final String id;
  final String label;
  final Map<String, dynamic> proxy;

  /// What the provider says this server is for (`serverDescription`). Their
  /// words, shown in place of the protocol — never inside [proxy], which is
  /// rendered into the engine config key by key.
  final String description;

  String get proxyType => proxy['type'] as String? ?? '';

  /// How the connection is carried, when that is worth saying: `xhttp`, `ws`,
  /// `grpc`… Empty for plain TCP, whose name tells the reader nothing and only
  /// takes room from the address, and for protocols that have no transport to
  /// choose (hysteria2 is QUIC).
  ///
  /// One value is not the engine's own: `httpupgrade` is stored as a websocket
  /// with a flag, and calling it `ws` would name a transport the server is not
  /// configured for.
  String get transport {
    final network = '${proxy['network'] ?? ''}'.toLowerCase();
    if (network.isEmpty || network == 'tcp') return '';
    if (network == 'ws') {
      final ws = proxy['ws-opts'];
      final upgrade = ws is Map && ws['v2ray-http-upgrade'] == true;
      return upgrade ? 'httpupgrade' : 'ws';
    }
    return network;
  }

  /// The line under the server's name: what it is, then where it is.
  ///
  /// "What it is" is the protocol and the transport — the pair every other
  /// client shows, because within one subscription the protocol alone is the
  /// same on every row and the transport is what tells them apart. A provider's
  /// description replaces that whole technical half; the address survives
  /// either way, being the only thing that separates two identically named
  /// entries.
  String get subtitle {
    final what = description.isNotEmpty
        ? description
        : [proxyType, transport].where((s) => s.isNotEmpty).join(' · ');
    final server = proxy['server'];
    if (server == null || '$server'.isEmpty) return what;
    return what.isEmpty ? '$server' : '$what · $server';
  }

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        proxy: Map<String, dynamic>.from(json['proxy'] as Map? ?? {}),
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'proxy': proxy,
        if (description.isNotEmpty) 'description': description,
      };
}
