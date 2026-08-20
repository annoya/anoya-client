import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'log.dart';
import 'network_extension_core.dart';
import 'norm_config.dart';

/// What we hold for one of a provider's rule lists.
class RuleListStatus {
  const RuleListStatus({
    required this.list,
    this.bytes = 0,
    this.updatedAt,
    this.error,
  });

  final RuleList list;

  /// Size on disk. Zero means we do not have it, whatever else is true.
  final int bytes;
  final DateTime? updatedAt;

  /// Why the last attempt failed, if it did. Kept even when [bytes] is
  /// non-zero: a refresh can fail over a copy that still works.
  final String? error;

  bool get available => bytes > 0;
}

/// Downloads and holds the rule lists a provider's policy refers to.
///
/// The engine could fetch these itself and deliberately does not: mihomo's
/// initial provider load runs inside config apply under a wait group, 20 s per
/// file (`hub/executor/executor.go`), which stalls a connect the way the geo
/// databases used to — and a failure there is only logged, leaving a rule that
/// silently matches nothing. Downloading here means the app knows the outcome
/// and can say so, and the engine is handed a plain local file.
///
/// Files live in the App Group container (mihomo's home dir, shared with the
/// tunnel extension), named by a digest of the URL so two providers publishing
/// different lists under the same name cannot collide.
class RuleListStore {
  /// Subdirectory of the shared container. Inside the engine's home dir, so
  /// mihomo's `IsSafePath` accepts the path we hand it.
  static const dirName = 'rulelists';

  /// Refresh interval for lists already on disk. Publishers ask for their own
  /// (`interval`), usually far more often; this is the app's own pace, and the
  /// user's data plan is the reason it is not theirs to set.
  static const refreshAge = Duration(days: 7);

  /// A rule list is text (or a compiled `mrs` blob) — tens of KB in practice.
  /// A publisher who serves us 20 MB has stopped serving a rule list, and the
  /// download stops rather than filling the container.
  static const maxBytes = 8 * 1024 * 1024;

  static Future<Directory?> _dir() async {
    final path = await NetworkExtensionCore.sharedDir();
    if (path == null) return null;
    final dir = Directory('$path/$dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The path the engine config points at. Stable for a given URL, so a
  /// refresh replaces the file the running config already names.
  static Future<String?> pathFor(RuleList list) async {
    final dir = await _dir();
    if (dir == null) return null;
    return '${dir.path}/${_fileName(list)}';
  }

  static String _fileName(RuleList list) {
    final digest = sha256.convert(utf8.encode(list.url)).toString().substring(0, 16);
    return '$digest.${list.format}';
  }

  /// Current state of every list in [lists], without touching the network.
  static Future<List<RuleListStatus>> status(List<RuleList> lists) async {
    final dir = await _dir();
    final out = <RuleListStatus>[];
    for (final l in lists) {
      if (dir == null) {
        out.add(RuleListStatus(list: l, error: 'shared container unavailable'));
        continue;
      }
      final f = File('${dir.path}/${_fileName(l)}');
      if (await f.exists()) {
        final stat = await f.stat();
        out.add(RuleListStatus(list: l, bytes: stat.size, updatedAt: stat.modified));
      } else {
        out.add(RuleListStatus(list: l, error: _lastError[l.url]));
      }
    }
    return out;
  }

  /// Why the last download of a URL failed. Memory-only on purpose: a failure
  /// is worth reporting in the session that saw it, and persisting it would
  /// outlive the network condition that caused it.
  static final Map<String, String> _lastError = {};

  /// Ensures every list is on disk, downloading what is missing and refreshing
  /// what is older than [refreshAge]. Never throws: a list that cannot be
  /// fetched is reported through [status], because the caller's job is to drop
  /// the rules that depend on it, not to fail the connect.
  static Future<List<RuleListStatus>> sync(List<RuleList> lists) async {
    for (final l in lists) {
      if (!l.isValid) continue;
      final path = await pathFor(l);
      if (path == null) continue;
      final f = File(path);
      final exists = await f.exists();
      if (exists) {
        final age = DateTime.now().difference((await f.stat()).modified);
        if (age < refreshAge) continue;
      }
      try {
        await _download(l, f);
        _lastError.remove(l.url);
        Log.i('rule list updated: ${l.name} from ${Uri.parse(l.url).host}');
      } catch (e) {
        // The host, not the URL: a list URL can carry a subscription secret.
        _lastError[l.url] = '${Uri.parse(l.url).host}: $e';
        Log.e('rule list download failed', '${l.name}: ${Uri.parse(l.url).host}');
      }
    }
    return status(lists);
  }

  static Future<void> _download(RuleList list, File dest) async {
    final client = http.Client();
    final tmp = File('${dest.path}.tmp');
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(list.url)))
          .timeout(kHttpTimeout);
      if (res.statusCode ~/ 100 != 2) {
        throw http.ClientException('rule list fetch failed (${res.statusCode})');
      }
      // Written under a temp name and renamed: a half-written file must never
      // shadow the copy the running tunnel is already using.
      final sink = tmp.openWrite();
      var written = 0;
      try {
        await for (final chunk in res.stream.timeout(kDownloadStallTimeout)) {
          written += chunk.length;
          if (written > maxBytes) {
            throw http.ClientException('rule list exceeds ${maxBytes ~/ 1024} KB');
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (written == 0) throw http.ClientException('rule list was empty');
      await tmp.rename(dest.path);
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Deletes files no live policy refers to any more — a provider that dropped
  /// a list, or a configuration the user removed. Called after a refresh.
  static Future<void> prune(Iterable<RuleList> keep) async {
    final dir = await _dir();
    if (dir == null) return;
    final wanted = keep.map(_fileName).toSet();
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (wanted.contains(name)) continue;
      // .tmp leftovers are also unwanted: nothing points at them.
      try {
        await e.delete();
      } catch (e) {
        Log.e('rule list prune failed', '$e');
      }
    }
  }

  /// Names of lists we actually hold, mapped to their file. What the renderer
  /// needs: a rule naming anything absent from here cannot run.
  static Future<Map<String, String>> availablePaths(List<RuleList> lists) async {
    final out = <String, String>{};
    for (final s in await status(lists)) {
      if (!s.available) continue;
      final path = await pathFor(s.list);
      if (path != null) out[s.list.name] = path;
    }
    return out;
  }

  /// Test seam: forget the in-memory failures between cases.
  static void debugReset() => _lastError.clear();
}
