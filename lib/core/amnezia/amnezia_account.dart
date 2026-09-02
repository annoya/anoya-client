import '../norm_config.dart';

/// One place a subscription may connect through, and the protocols it offers
/// there.
class AmneziaCountry {
  const AmneziaCountry({
    required this.code,
    required this.name,
    required this.flagCode,
    required this.protocols,
  });

  /// What the gateway is asked for. May carry a region suffix (`nl-ams-1`),
  /// so it is never shown to the user and never used as a flag.
  final String code;

  final String name;

  /// A plain ISO-3166 code for the flag, which the routing code above is not.
  final String flagCode;

  /// `awg`, `vless`, or both.
  final List<String> protocols;

  factory AmneziaCountry.fromJson(Map<String, dynamic> j) {
    final code = '${j['server_country_code'] ?? ''}';
    final l10n = '${j['server_country_code_l10n'] ?? ''}';
    return AmneziaCountry(
      code: code,
      name: '${j['server_country_name'] ?? code}',
      // The routing code may be `nl-ams-1`; a flag needs the country half.
      flagCode: (l10n.isNotEmpty ? l10n : code.split('-').first).toUpperCase(),
      protocols: [
        for (final p in (j['available_protocols'] as List<dynamic>? ?? const []))
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

/// What the gateway says about a subscription as a whole.
///
/// Every field is optional because a free subscription genuinely has none of
/// them: it answers with a description and nothing else — no locations, no
/// device count, no end date. That is not an error to paper over, it is the
/// shape of the product, and the screen shows only what arrived.
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

  /// 0 when the gateway did not say — which is different from "none".
  final int activeDevices;
  final int maxDevices;

  final String description;

  /// A subscription the gateway placed no end on is not expired; only one it
  /// dated and that date has passed.
  bool get expired => endsAt != null && endsAt!.isBefore(DateTime.now().toUtc());

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

/// Everything Amnezia-specific about a configuration, in one field so that
/// nothing else in the app has to grow a branch for it.
class AmneziaState {
  const AmneziaState({
    required this.serviceType,
    required this.serviceProtocol,
    required this.userCountryCode,
    this.account = const AmneziaAccount(),
    this.expiries = const {},
  });

  /// `amnezia-premium` | `amnezia-free` | `external-premium`.
  final String serviceType;

  /// What the key was issued for. A location may offer more, and the app
  /// presents each pairing separately, so this is only the default.
  final String serviceProtocol;

  final String userCountryCode;
  final AmneziaAccount account;

  /// When the gateway said the held config stops being accepted. A map rather
  /// than a field because it is keyed by the selection it belongs to, and only
  /// ever holds the one being used.
  final Map<String, DateTime> expiries;

  /// Whether the gateway named anywhere to connect through. A subscription
  /// that answered with no countries has nothing to offer yet — which is a
  /// state to report, not one to invent a location for.
  bool get offersLocations => account.countries.isNotEmpty;

  AmneziaState copyWith({
    String? serviceProtocol,
    AmneziaAccount? account,
    Map<String, DateTime>? expiries,
  }) =>
      AmneziaState(
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
            (j['account'] as Map?)?.cast<String, dynamic>() ?? const {}),
        expiries: _dates(j['expiries']),
      );

  Map<String, dynamic> toJson() => {
        'service_type': serviceType,
        'service_protocol': serviceProtocol,
        'user_country_code': userCountryCode,
        'account': account.toJson(),
        if (expiries.isNotEmpty)
          'expiries': {
            for (final e in expiries.entries) e.key: e.value.toIso8601String()
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

/// The id of the location that stands for one country and one protocol.
///
/// Amnezia issues a config per pairing, and switching either one costs a
/// round trip to the gateway — so the app presents them as what they are, two
/// separate places to connect through, rather than a location with a hidden
/// second control.
String amneziaLocationId(String countryCode, String protocol) =>
    'amnezia_${countryCode}_$protocol';

/// How a protocol is written where the user reads it.
String amneziaProtocolLabel(String protocol) => switch (protocol) {
      'awg' => 'AmneziaWG',
      'vless' => 'VLESS',
      final other => other.toUpperCase(),
    };

/// The locations a subscription offers, as the picker will show them.
///
/// Each carries no proxy yet: Amnezia issues the real settings only when asked
/// for one, so these are placeholders until [AmneziaSource] resolves them.
List<Location> amneziaLocations(AmneziaState state) {
  return [
    for (final c in state.account.countries)
      for (final p in c.protocols)
        Location(
          id: amneziaLocationId(c.code, p),
          // The country's own name, which is also what the flag is derived
          // from — the routing code (`nl-ams-1`) would resolve to nothing.
          label: c.name,
          proxy: const {},
          description: amneziaProtocolLabel(p),
        ),
  ];
}

/// Which country and protocol a location id names. Null for anything that is
/// not one of ours.
({String country, String protocol})? amneziaLocationParts(String id) {
  if (!id.startsWith('amnezia_')) return null;
  final rest = id.substring('amnezia_'.length);
  final cut = rest.lastIndexOf('_');
  if (cut <= 0) return null;
  return (country: rest.substring(0, cut), protocol: rest.substring(cut + 1));
}
