import 'norm_config.dart';
import 'dns_plan.dart';
import 'json_file_store.dart';

const kLanDirectRules = [
  RoutingRule(type: 'ip-cidr', values: ['10.0.0.0/8'], action: 'direct'),
  RoutingRule(type: 'ip-cidr', values: ['172.16.0.0/12'], action: 'direct'),
  RoutingRule(type: 'ip-cidr', values: ['192.168.0.0/16'], action: 'direct'),
  RoutingRule(type: 'ip-cidr', values: ['169.254.0.0/16'], action: 'direct'),
  RoutingRule(type: 'ip-cidr', values: ['224.0.0.0/4'], action: 'direct'),
];

Routing withLanDirect(Routing routing) {
  final ahead = <RoutingRule>[];
  final rest = <RoutingRule>[];
  for (final r in routing.rules) {
    if (r.type != 'ip-cidr') {
      rest.add(r);
      continue;
    }
    final inside = r.values.where(withinLan).toList();
    final outside = r.values.where((v) => !withinLan(v)).toList();
    if (inside.isNotEmpty) ahead.add(r.copyWith(values: inside));
    if (outside.isNotEmpty) rest.add(r.copyWith(values: outside));
  }
  return Routing(
    mode: routing.mode,
    rules: [...ahead, ...kLanDirectRules, ...rest],
    lists: routing.lists,
  );
}

bool withinLan(String cidr) {
  final net = _v4Net(cidr);
  if (net == null) return false;
  for (final lan in kLanDirectRules.expand((r) => r.values)) {
    final l = _v4Net(lan)!;
    if (net.bits >= l.bits && net.addr & l.mask == l.addr & l.mask) return true;
  }
  return false;
}

({int addr, int bits, int mask})? _v4Net(String cidr) {
  final slash = cidr.indexOf('/');
  if (slash < 0) return null;
  final bits = int.tryParse(cidr.substring(slash + 1));
  if (bits == null || bits > 32) return null;
  final List<int> b;
  try {
    b = Uri.parseIPv4Address(cidr.substring(0, slash));
  } on FormatException {
    return null;
  }
  return (
    addr: b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3],
    bits: bits,
    mask: bits == 0 ? 0 : 0xFFFFFFFF << (32 - bits) & 0xFFFFFFFF,
  );
}

class RoutingPrefs {
  const RoutingPrefs({
    this.lanDirect = true,
    this.dnsProtection = false,
    this.geoipUrl = defaultGeoipUrl,
    this.geositeUrl = defaultGeositeUrl,
    this.geoAutoUpdate = true,
    this.geoUpdatedAt,
    this.defaultDns = kFallbackNameserver,
  });

  static const defaultGeoipUrl =
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb';
  static const defaultGeositeUrl =
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat';

  final bool lanDirect;

  final bool dnsProtection;

  final String defaultDns;

  final String geoipUrl;
  final String geositeUrl;
  final bool geoAutoUpdate;
  final DateTime? geoUpdatedAt;

  RoutingPrefs copyWith({
    bool? lanDirect,
    bool? dnsProtection,
    String? defaultDns,
    String? geoipUrl,
    String? geositeUrl,
    bool? geoAutoUpdate,
    DateTime? geoUpdatedAt,
  }) => RoutingPrefs(
    lanDirect: lanDirect ?? this.lanDirect,
    dnsProtection: dnsProtection ?? this.dnsProtection,
    defaultDns: defaultDns ?? this.defaultDns,
    geoipUrl: geoipUrl ?? this.geoipUrl,
    geositeUrl: geositeUrl ?? this.geositeUrl,
    geoAutoUpdate: geoAutoUpdate ?? this.geoAutoUpdate,
    geoUpdatedAt: geoUpdatedAt ?? this.geoUpdatedAt,
  );

  factory RoutingPrefs.fromJson(Map<String, dynamic> j) => RoutingPrefs(
    lanDirect: j['lan_direct'] as bool? ?? true,
    dnsProtection: j['dns_protection'] as bool? ?? false,
    defaultDns: j['default_dns'] as String? ?? kFallbackNameserver,
    geoipUrl: j['geoip_url'] as String? ?? defaultGeoipUrl,
    geositeUrl: j['geosite_url'] as String? ?? defaultGeositeUrl,
    geoAutoUpdate: j['geo_auto_update'] as bool? ?? true,
    geoUpdatedAt: j['geo_updated_at'] != null
        ? DateTime.tryParse(j['geo_updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'lan_direct': lanDirect,
    'dns_protection': dnsProtection,
    'default_dns': defaultDns,
    'geoip_url': geoipUrl,
    'geosite_url': geositeUrl,
    'geo_auto_update': geoAutoUpdate,
    if (geoUpdatedAt != null) 'geo_updated_at': geoUpdatedAt!.toIso8601String(),
  };
}

class RoutingPrefsStore {
  static final _store = JsonFileStore('routing_prefs.json');

  static Future<RoutingPrefs> load() => _store.load(
    (j) => j is Map
        ? RoutingPrefs.fromJson(Map<String, dynamic>.from(j))
        : const RoutingPrefs(),
    const RoutingPrefs(),
  );

  static Future<void> save(RoutingPrefs prefs) => _store.save(prefs.toJson());
}
