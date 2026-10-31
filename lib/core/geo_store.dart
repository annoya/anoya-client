import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'download.dart';
import 'log.dart';
import 'network_extension_core.dart';
import 'routing_prefs.dart';

class GeoStatus {
  const GeoStatus({this.geoipBytes = 0, this.geositeBytes = 0});

  final int geoipBytes;
  final int geositeBytes;

  bool get downloaded => geoipBytes > 0 && geositeBytes > 0;
}

class GeoStore {
  static const geoipFile = 'geoip.metadb';
  static const geositeFile = 'GeoSite.dat';

  static const autoUpdateAge = Duration(days: 7);

  @visibleForTesting
  static Duration stallTimeout = kDownloadStallTimeout;

  static Future<Directory?> _dir() async {
    final path = await NetworkExtensionCore.sharedDir();
    if (path == null) return null;
    return Directory(path);
  }

  static Future<GeoStatus> status() async {
    final dir = await _dir();
    if (dir == null) return const GeoStatus();
    return GeoStatus(
      geoipBytes: await _size(File('${dir.path}/$geoipFile')),
      geositeBytes: await _size(File('${dir.path}/$geositeFile')),
    );
  }

  static Future<void> _fetchTo(String url, File dest) => downloadToFile(
    Uri.parse(url),
    dest,
    what: 'geo database',
    stallTimeout: stallTimeout,
  );

  static Future<int> _size(File f) async =>
      await f.exists() ? await f.length() : 0;

  static Future<void> download() async {
    final dir = await _dir();
    if (dir == null) throw StateError('shared container unavailable');
    final prefs = await RoutingPrefsStore.load();
    await _fetchTo(prefs.geoipUrl, File('${dir.path}/$geoipFile'));
    await _fetchTo(prefs.geositeUrl, File('${dir.path}/$geositeFile'));
    final fresh = await RoutingPrefsStore.load();
    await RoutingPrefsStore.save(fresh.copyWith(geoUpdatedAt: DateTime.now()));
    Log.i('geo: databases updated');
  }

  static Future<void> maybeAutoUpdate() async {
    try {
      final prefs = await RoutingPrefsStore.load();
      if (!prefs.geoAutoUpdate) return;
      if (!(await status()).downloaded) return;
      final at = prefs.geoUpdatedAt;
      if (at != null && DateTime.now().difference(at) < autoUpdateAge) return;
      await download();
    } catch (e) {
      Log.e('geo: auto-update failed', '$e');
    }
  }
}
