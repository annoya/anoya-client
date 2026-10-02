import '../l10n/l10n.dart';

class NormConfig {
  NormConfig({
    required this.version,
    required this.account,
    required this.locations,
    this.groups = const [],
    this.routing,
    this.dns = const [],
    this.defaultDns = '',
  });

  final int version;
  final Account account;
  final List<Location> locations;

  final List<ProxyGroup> groups;

  final Routing? routing;

  final List<String> dns;

  final String defaultDns;

  factory NormConfig.fromJson(Map<String, dynamic> json) {
    final locs = (json['locations'] as List<dynamic>? ?? [])
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
    final routingJson = json['routing'];
    return NormConfig(
      version: json['version'] as int? ?? 1,
      account: Account.fromJson(json['account'] as Map<String, dynamic>? ?? {}),
      locations: locs,
      routing: routingJson is Map
          ? Routing.fromJson(Map<String, dynamic>.from(routingJson))
          : null,
      dns: (json['dns'] as List<dynamic>? ?? []).whereType<String>().toList(),
      defaultDns: json['default_dns'] as String? ?? '',
    );
  }
}

class Routing {
  const Routing({
    required this.mode,
    required this.rules,
    this.lists = const [],
  });

  final String mode;
  final List<RoutingRule> rules;

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

  final String name;

  final String type;

  final List<String> members;

  final String testUrl;

  final int intervalSeconds;

  final int tolerance;

  final String strategy;

  static const types = ['url-test', 'fallback', 'load-balance', 'relay'];
  static const strategies = [
    'round-robin',
    'consistent-hashing',
    'sticky-sessions',
  ];

  String get id => 'group:$name';

  static bool isGroupId(String id) => id.startsWith('group:');

  bool get isValid =>
      name.isNotEmpty && types.contains(type) && members.isNotEmpty;

  String describe(int memberCount) => switch (type) {
    'url-test' => L10n.current.proxyGroupUrlTest(memberCount),
    'fallback' => L10n.current.proxyGroupFallback(memberCount),
    'load-balance' => L10n.current.proxyGroupLoadBalance(memberCount),
    'relay' => L10n.current.proxyGroupRelay(memberCount),
    _ => L10n.current.commonServersCount(memberCount),
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

class RuleList {
  const RuleList({
    required this.name,
    required this.url,
    required this.behavior,
    this.format = 'yaml',
  });

  final String name;
  final String url;

  final String behavior;

  final String format;

  static const behaviors = ['domain', 'ipcidr', 'classical'];
  static const formats = ['yaml', 'text', 'mrs'];
  static final _nameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

  bool get isValid {
    if (!_nameRe.hasMatch(name)) return false;
    if (!behaviors.contains(behavior) || !formats.contains(format)) {
      return false;
    }
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  factory RuleList.fromJson(Map<String, dynamic> json) => RuleList(
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    behavior: json['behavior'] as String? ?? '',
    format: json['format'] as String? ?? 'yaml',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'behavior': behavior,
    'format': format,
  };
}

class RoutingRule {
  const RoutingRule({
    required this.type,
    required this.value,
    required this.action,
    this.noResolve = false,
  });

  final String type;
  final String value;
  final String action;

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
    'domain-suffix',
    'domain-keyword',
    'domain-exact',
    'domain-regex',
    'ip-cidr',
    'process-name',
    'geoip',
    'geosite',
    'rule-list',
  ];
  static const actions = ['proxy', 'direct', 'block'];

  static final _domainRe = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');
  static final _cidrRe = RegExp(r'^[0-9a-fA-F:.]+/\d{1,3}$');
  static final _processRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$');
  static final _geoipRe = RegExp(r'^[A-Za-z]{2}$');
  static final _geositeRe = RegExp(r'^[a-z0-9][a-z0-9@.!-]*$');
  static final _listRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final _regexRe = RegExp(r'^[^,#\r\n]{1,256}$');

  bool get needsGeoData => type == 'geoip' || type == 'geosite';

  bool get needsRuleList => type == 'rule-list';

  bool get isValid {
    if (!actions.contains(action)) return false;
    switch (type) {
      case 'domain-suffix':
      case 'domain-keyword':
      case 'domain-exact':
        return _domainRe.hasMatch(value);
      case 'domain-regex':
        if (!_regexRe.hasMatch(value)) return false;
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
  final String status;
  final DateTime? expiresAt;
  final int usedBytes;
  final int dataLimit;

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
    this.countryCode = '',
  });

  final String id;
  final String label;
  final Map<String, dynamic> proxy;

  final String description;

  final String countryCode;

  String get proxyType => proxy['type'] as String? ?? '';

  bool get isPlaceholder => proxy.isEmpty;

  String get transport {
    if (proxyType == 'hysteria2') return 'QUIC';
    final network = '${proxy['network'] ?? ''}'.toLowerCase();
    if (network == 'ws') {
      final ws = proxy['ws-opts'];
      final upgrade = ws is Map && ws['v2ray-http-upgrade'] == true;
      return upgrade ? 'HTTPUpgrade' : 'WS';
    }
    return switch (network) {
      '' || 'tcp' => 'TCP',
      'grpc' => 'gRPC',
      'h2' => 'HTTP/2',
      'http' => 'HTTP',
      'xhttp' => 'XHTTP',
      _ => network.toUpperCase(),
    };
  }

  String get security {
    if (proxy['reality-opts'] != null || proxy['reality'] != null) {
      return 'Reality';
    }
    if (proxyType == 'trojan' || proxyType == 'hysteria2') return 'TLS';
    return proxy['tls'] == true ? 'TLS' : 'No TLS';
  }

  String get protocol => switch (proxyType) {
    'vless' => 'VLESS',
    'vmess' => 'VMess',
    'trojan' => 'Trojan',
    'ss' => 'Shadowsocks',
    'hysteria2' => 'Hysteria2',
    final other => other.toUpperCase(),
  };

  String get subtitle {
    if (description.isNotEmpty) return description;
    if (isPlaceholder) return '';
    return [protocol, transport, security].join(' · ');
  }

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    proxy: Map<String, dynamic>.from(json['proxy'] as Map? ?? {}),
    description: json['description'] as String? ?? '',
    countryCode: json['country_code'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'proxy': proxy,
    if (description.isNotEmpty) 'description': description,
    if (countryCode.isNotEmpty) 'country_code': countryCode,
  };
}
