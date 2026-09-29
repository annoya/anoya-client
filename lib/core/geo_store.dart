import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
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

  static Future<void> _fetchTo(String url, File dest) async {
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(kHttpTimeout);
      if (res.statusCode ~/ 100 != 2) {
        throw http.ClientException(
          'geo download failed (${res.statusCode})',
          Uri.parse(url),
        );
      }
      final tmp = File('${dest.path}.tmp');
      final sink = tmp.openWrite();
      try {
        await sink.addStream(res.stream.timeout(kDownloadStallTimeout));
      } finally {
        await sink.close();
      }
      if (await tmp.length() == 0) {
        await tmp.delete();
        throw http.ClientException('geo download was empty', Uri.parse(url));
      }
      await tmp.rename(dest.path);
    } catch (_) {
      final tmp = File('${dest.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    } finally {
      client.close();
    }
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
