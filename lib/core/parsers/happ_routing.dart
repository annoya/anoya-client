import '../norm_config.dart';

typedef HappRules = ({List<RoutingRule> rules, List<String> dropped});

HappRules happRules(Map<dynamic, dynamic> doc) {
  final rules = <RoutingRule>[];
  final dropped = <String>[];

  List<String> list(String key) => [
    for (final v in (doc[key] as List<dynamic>? ?? const []))
      if (v is String && v.trim().isNotEmpty) v.trim(),
  ];

  void sites(String key, String action) {
    for (final entry in list(key)) {
      final rule = _site(entry, action);
      if (rule != null) {
        rules.add(rule);
      } else {
        dropped.add(entry.contains(':') ? '${entry.split(':').first}:' : entry);
      }
    }
  }

  void ips(String key, String action) {
    for (final entry in list(key)) {
      final rule = _ip(entry, action);
      if (rule != null) {
        rules.add(rule);
      } else {
        dropped.add(entry);
      }
    }
  }

  sites('BlockSites', 'block');
  ips('BlockIp', 'block');
  sites('ProxySites', 'proxy');
  ips('ProxyIp', 'proxy');
  sites('DirectSites', 'direct');
  ips('DirectIp', 'direct');
  return (rules: rules, dropped: dropped);
}

bool? happGlobalProxy(Object? value) => switch ('$value'.toLowerCase()) {
  'true' => true,
  'false' => false,
  _ => null,
};

RoutingRule? _site(String entry, String action) {
  final colon = entry.indexOf(':');
  final prefix = colon > 0 ? entry.substring(0, colon).toLowerCase() : '';
  final value = colon > 0 ? entry.substring(colon + 1) : entry;
  final type = switch (prefix) {
    '' || 'domain' => 'domain-suffix',
    'full' => 'domain-exact',
    'keyword' => 'domain-keyword',
    'regexp' => 'domain-regex',
    'geosite' => 'geosite',
    _ => null,
  };
  if (type == null) return null;
  final rule = RoutingRule(
    type: type,
    values: [type == 'geosite' ? value.toLowerCase() : value],
    action: action,
  );
  return rule.isValid ? rule : null;
}

RoutingRule? _ip(String entry, String action) {
  if (entry.toLowerCase().startsWith('geoip:')) {
    final rule = RoutingRule(
      type: 'geoip',
      values: [entry.substring(6).toUpperCase()],
      action: action,
    );
    return rule.isValid ? rule : null;
  }
  final cidr = entry.contains('/')
      ? entry
      : '$entry/${entry.contains(':') ? 128 : 32}';
  final rule = RoutingRule(type: 'ip-cidr', values: [cidr], action: action);
  return rule.isValid ? rule : null;
}
