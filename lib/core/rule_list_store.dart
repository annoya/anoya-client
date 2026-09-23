import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'log.dart';
import 'network_extension_core.dart';
import 'norm_config.dart';

class RuleListStatus {
  const RuleListStatus({
    required this.list,
    this.bytes = 0,
    this.updatedAt,
    this.error,
  });

  final RuleList list;

  final int bytes;
  final DateTime? updatedAt;

  final String? error;

  bool get available => bytes > 0;
}

class RuleListStore {
  // Inside the engine's home dir so mihomo's `IsSafePath` accepts it.
  static const dirName = 'rulelists';

  static const refreshAge = Duration(days: 7);

  static const maxBytes = 8 * 1024 * 1024;

  static Future<Directory?> _dir() async {
    final path = await NetworkExtensionCore.sharedDir();
    if (path == null) return null;
    final dir = Directory('$path/$dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String?> pathFor(RuleList list) async {
    final dir = await _dir();
    if (dir == null) return null;
    return '${dir.path}/${_fileName(list)}';
  }

  static String _fileName(RuleList list) {
    final digest = sha256
        .convert(utf8.encode(list.url))
        .toString()
        .substring(0, 16);
    return '$digest.${list.format}';
  }

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
        out.add(
          RuleListStatus(list: l, bytes: stat.size, updatedAt: stat.modified),
        );
      } else {
        out.add(RuleListStatus(list: l, error: _lastError[l.url]));
      }
    }
    return out;
  }

  static final Map<String, String> _lastError = {};

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
        // Host only: a list URL can carry a subscription secret.
        _lastError[l.url] = '${Uri.parse(l.url).host}: $e';
        Log.e(
          'rule list download failed',
          '${l.name}: ${Uri.parse(l.url).host}',
        );
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
        throw http.ClientException(
          'rule list fetch failed (${res.statusCode})',
        );
      }
      final sink = tmp.openWrite();
      var written = 0;
      try {
        await for (final chunk in res.stream.timeout(kDownloadStallTimeout)) {
          written += chunk.length;
          if (written > maxBytes) {
            throw http.ClientException(
              'rule list exceeds ${maxBytes ~/ 1024} KB',
            );
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

  static Future<void> prune(Iterable<RuleList> keep) async {
    final dir = await _dir();
    if (dir == null) return;
    final wanted = keep.map(_fileName).toSet();
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (wanted.contains(name)) continue;
      try {
        await e.delete();
      } catch (e) {
        Log.e('rule list prune failed', '$e');
      }
    }
  }

  static Future<Map<String, String>> availablePaths(
    List<RuleList> lists,
  ) async {
    final out = <String, String>{};
    for (final s in await status(lists)) {
      if (!s.available) continue;
      final path = await pathFor(s.list);
      if (path != null) out[s.list.name] = path;
    }
    return out;
  }

  static void debugReset() => _lastError.clear();
}
