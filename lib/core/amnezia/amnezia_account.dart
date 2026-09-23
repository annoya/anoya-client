import '../norm_config.dart';

class AmneziaCountry {
  const AmneziaCountry({
    required this.code,
    required this.name,
    required this.flagCode,
    required this.protocols,
  });

  final String code;

  final String name;

  final String flagCode;

  final List<String> protocols;

  factory AmneziaCountry.fromJson(Map<String, dynamic> j) {
    final code = '${j['server_country_code'] ?? ''}';
    final l10n = '${j['server_country_code_l10n'] ?? ''}';
    return AmneziaCountry(
      code: code,
      name: '${j['server_country_name'] ?? code}',
      flagCode: (l10n.isNotEmpty ? l10n : code.split('-').first).toUpperCase(),
      protocols: [
        for (final p
            in (j['available_protocols'] as List<dynamic>? ?? const []))
          if (p is String && p.isNotEmpty) p,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'server_country_code': code,
    'server_country_name': name,
    'server_country_code_l10n': flagCode,
    'available_protocols': protocols,
  };
}

class AmneziaAccount {
  const AmneziaAccount({
    this.countries = const [],
    this.endsAt,
    this.activeDevices = 0,
    this.maxDevices = 0,
    this.description = '',
  });

  final List<AmneziaCountry> countries;
  final DateTime? endsAt;

  final int activeDevices;
  final int maxDevices;

  final String description;

  bool get expired =>
      endsAt != null && endsAt!.isBefore(DateTime.now().toUtc());

  bool get hasDeviceCount => maxDevices > 0;

  factory AmneziaAccount.fromJson(Map<String, dynamic> j) => AmneziaAccount(
    countries: [
      for (final c in (j['available_countries'] as List<dynamic>? ?? const []))
        if (c is Map) AmneziaCountry.fromJson(c.cast<String, dynamic>()),
    ],
    endsAt: DateTime.tryParse('${j['subscription_end_date'] ?? ''}')?.toUtc(),
    activeDevices: (j['active_device_count'] as num?)?.toInt() ?? 0,
    maxDevices: (j['max_device_count'] as num?)?.toInt() ?? 0,
    description: '${j['subscription_description'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    if (countries.isNotEmpty)
      'available_countries': [for (final c in countries) c.toJson()],
    if (endsAt != null) 'subscription_end_date': endsAt!.toIso8601String(),
    if (activeDevices > 0) 'active_device_count': activeDevices,
    if (maxDevices > 0) 'max_device_count': maxDevices,
    if (description.isNotEmpty) 'subscription_description': description,
  };
}

class AmneziaState {
  const AmneziaState({
    required this.serviceType,
    required this.serviceProtocol,
    required this.userCountryCode,
    this.account = const AmneziaAccount(),
    this.expiries = const {},
  });

  final String serviceType;

  final String serviceProtocol;

  final String userCountryCode;
  final AmneziaAccount account;

  final Map<String, DateTime> expiries;

  bool get offersLocations => account.countries.isNotEmpty;

  AmneziaState copyWith({
    String? serviceProtocol,
    AmneziaAccount? account,
    Map<String, DateTime>? expiries,
  }) => AmneziaState(
    serviceType: serviceType,
    serviceProtocol: serviceProtocol ?? this.serviceProtocol,
    userCountryCode: userCountryCode,
    account: account ?? this.account,
    expiries: expiries ?? this.expiries,
  );

  factory AmneziaState.fromJson(Map<String, dynamic> j) => AmneziaState(
    serviceType: '${j['service_type'] ?? ''}',
    serviceProtocol: '${j['service_protocol'] ?? ''}',
    userCountryCode: '${j['user_country_code'] ?? ''}',
    account: AmneziaAccount.fromJson(
      (j['account'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    expiries: _dates(j['expiries']),
  );

  Map<String, dynamic> toJson() => {
    'service_type': serviceType,
    'service_protocol': serviceProtocol,
    'user_country_code': userCountryCode,
    'account': account.toJson(),
    if (expiries.isNotEmpty)
      'expiries': {
        for (final e in expiries.entries) e.key: e.value.toIso8601String(),
      },
  };

  static Map<String, DateTime> _dates(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      final d = DateTime.tryParse('$v');
      if (d != null) out['$k'] = d.toUtc();
    });
    return out;
  }
}

String amneziaLocationId(String countryCode, String protocol) =>
    'amnezia_${countryCode}_$protocol';

String amneziaProtocolLabel(String protocol) => switch (protocol) {
  'awg' => 'AmneziaWG',
  'vless' => 'VLESS',
  final other => other.toUpperCase(),
};

List<Location> amneziaLocations(AmneziaState state) {
  return [
    for (final c in state.account.countries)
      for (final p in c.protocols)
        Location(
          id: amneziaLocationId(c.code, p),
          label: c.name,
          proxy: const {},
          description: amneziaProtocolLabel(p),
        ),
  ];
}

({String country, String protocol})? amneziaLocationParts(String id) {
  if (!id.startsWith('amnezia_')) return null;
  final rest = id.substring('amnezia_'.length);
  final cut = rest.lastIndexOf('_');
  if (cut <= 0) return null;
  return (country: rest.substring(0, cut), protocol: rest.substring(cut + 1));
}
