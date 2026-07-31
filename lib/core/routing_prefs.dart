import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';
import 'norm_config.dart';

/// Hidden rules prepended (ahead of any policy, managed included) when
/// [RoutingPrefs.lanDirect] is on: private, link-local and multicast ranges
/// bypass the VPN, the standard "local network access" behavior.
const kLanDirectRules = [
  RoutingRule(type: 'ip-cidr', value: '10.0.0.0/8', action: 'direct'),
  RoutingRule(type: 'ip-cidr', value: '172.16.0.0/12', action: 'direct'),
  RoutingRule(type: 'ip-cidr', value: '192.168.0.0/16', action: 'direct'),
  RoutingRule(type: 'ip-cidr', value: '169.254.0.0/16', action: 'direct'),
  RoutingRule(type: 'ip-cidr', value: '224.0.0.0/4', action: 'direct'),
];

/// Device-level routing preferences that sit outside rule sets:
///  - [lanDirect]: LAN traffic bypasses the VPN (rendered as hidden ip-cidr →
///    direct rules ahead of any policy, managed ones included);
///  - GeoIP/GeoSite database source URLs, auto-update flag and last update.
/// Persisted as routing_prefs.json in app-support.
class RoutingPrefs {
  const RoutingPrefs({
    this.lanDirect = true,
    this.geoipUrl = defaultGeoipUrl,
    this.geositeUrl = defaultGeositeUrl,
    this.geoAutoUpdate = true,
    this.geoUpdatedAt,
  });

  // mihomo's own default release artifacts (MetaCubeX/meta-rules-dat).
  static const defaultGeoipUrl =
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb';
  static const defaultGeositeUrl =
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat';

  final bool lanDirect;
  final String geoipUrl;
  final String geositeUrl;
  final bool geoAutoUpdate;
  final DateTime? geoUpdatedAt;

  RoutingPrefs copyWith({
    bool? lanDirect,
    String? geoipUrl,
    String? geositeUrl,
    bool? geoAutoUpdate,
    DateTime? geoUpdatedAt,
  }) =>
      RoutingPrefs(
        lanDirect: lanDirect ?? this.lanDirect,
        geoipUrl: geoipUrl ?? this.geoipUrl,
        geositeUrl: geositeUrl ?? this.geositeUrl,
        geoAutoUpdate: geoAutoUpdate ?? this.geoAutoUpdate,
        geoUpdatedAt: geoUpdatedAt ?? this.geoUpdatedAt,
      );

  factory RoutingPrefs.fromJson(Map<String, dynamic> j) => RoutingPrefs(
        lanDirect: j['lan_direct'] as bool? ?? true,
        geoipUrl: j['geoip_url'] as String? ?? defaultGeoipUrl,
        geositeUrl: j['geosite_url'] as String? ?? defaultGeositeUrl,
        geoAutoUpdate: j['geo_auto_update'] as bool? ?? true,
        geoUpdatedAt: j['geo_updated_at'] != null
            ? DateTime.tryParse(j['geo_updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'lan_direct': lanDirect,
        'geoip_url': geoipUrl,
        'geosite_url': geositeUrl,
        'geo_auto_update': geoAutoUpdate,
        if (geoUpdatedAt != null) 'geo_updated_at': geoUpdatedAt!.toIso8601String(),
      };
}

class RoutingPrefsStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/routing_prefs.json');
  }

  static Future<RoutingPrefs> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const RoutingPrefs();
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return const RoutingPrefs();
      return RoutingPrefs.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      Log.e('routing prefs: could not load', '$e');
      return const RoutingPrefs();
    }
  }

  static Future<void> save(RoutingPrefs prefs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(prefs.toJson()));
  }
}
