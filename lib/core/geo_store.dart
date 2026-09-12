import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'log.dart';
import 'network_extension_core.dart';
import 'routing_prefs.dart';

/// Presence/size of the local geo databases.
class GeoStatus {
  const GeoStatus({this.geoipBytes = 0, this.geositeBytes = 0});

  final int geoipBytes;
  final int geositeBytes;

  /// geoip/geosite rules only work when both databases are present.
  bool get downloaded => geoipBytes > 0 && geositeBytes > 0;
}

/// Manages the GeoIP/GeoSite database files that geoip/geosite rules depend
/// on. Files live in the App Group container (mihomo's home dir, shared with
/// the tunnel extension) under the exact names mihomo looks up. The host app
/// downloads them — never the engine (geo-auto-update stays off): a 20+ MB
/// GitHub download during tunnel start is precisely what must not happen.
class GeoStore {
  // Filenames match mihomo's constant.Path lookups.
  static const geoipFile = 'geoip.metadb';
  static const geositeFile = 'GeoSite.dat';

  /// Max age before the auto-updater re-downloads (weekly, per the settings UI).
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

  /// Download both databases from the configured URLs and stamp
  /// [RoutingPrefs.geoUpdatedAt]. Throws on any failure (partial downloads are
  /// discarded — a truncated database must never shadow a working one).
  static Future<void> download() async {
    final dir = await _dir();
    if (dir == null) throw StateError('shared container unavailable');
    final prefs = await RoutingPrefsStore.load();
    await _fetchTo(prefs.geoipUrl, File('${dir.path}/$geoipFile'));
    await _fetchTo(prefs.geositeUrl, File('${dir.path}/$geositeFile'));
    // Re-load before stamping: the two downloads take minutes on a slow link,
    // and saving the snapshot from before them would silently revert any
    // setting the user changed meanwhile (lanDirect, source URLs).
    final fresh = await RoutingPrefsStore.load();
    await RoutingPrefsStore.save(fresh.copyWith(geoUpdatedAt: DateTime.now()));
    Log.i('geo: databases updated');
  }

  static Future<void> _fetchTo(String url, File dest) async {
    // Stream to disk rather than buffering: each database is 4-20 MB, and two
    // of them held in memory at once is real pressure on iOS.
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
      // Write to a temp name then rename: keep the old database usable if we
      // die mid-write.
      final tmp = File('${dest.path}.tmp');
      final sink = tmp.openWrite();
      try {
        // An idle timeout, not a total one: the transfer is allowed to be slow
        // on a slow link, but a connection that stops delivering must not hold
        // the download (and the UI's busy state) open indefinitely — which is
        // what the header timeout above does not cover.
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
      // Leave no half-written file behind for the next run to find.
      final tmp = File('${dest.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Weekly refresh of already-downloaded databases (never a first download —
  /// pulling 20+ MB the user didn't ask for is not okay). Errors are logged,
  /// not thrown: this runs opportunistically at app start.
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
