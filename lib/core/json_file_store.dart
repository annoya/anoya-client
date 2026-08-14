import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';

/// The one way this app persists a JSON document. Every store used to carry
/// its own copy of this logic, and the copies shared two data-loss bugs: a
/// non-atomic write (a crash mid-write truncates the file) combined with a
/// catch-all load that returns the default — so the next save would persist
/// the default and make the loss permanent. Centralizing fixes it once.
class JsonFileStore {
  JsonFileStore(this.filename);

  /// e.g. "profiles.json"; lives in the application-support directory.
  final String filename;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$filename');
  }

  /// Reads and decodes the file; [fallback] on absence or any damage.
  /// Damage is logged but never thrown: the caller gets a working default and
  /// the file stays untouched until the next explicit save.
  Future<T> load<T>(T Function(dynamic json) decode, T fallback) async {
    try {
      final f = await _file();
      if (!await f.exists()) return fallback;
      return decode(jsonDecode(await f.readAsString()));
    } catch (e) {
      Log.e('$filename: could not load', '$e');
      return fallback;
    }
  }

  /// Atomic write: temp file + rename (+flush), so a crash at any point leaves
  /// either the old content or the new — never a truncated file.
  Future<void> save(Object json) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }
}

/// Decodes a JSON list entry-by-entry, skipping (and logging) damaged entries
/// instead of discarding the whole list — one bad element must not cost the
/// user everything else in the file.
List<T> decodeListLenient<T>(
    dynamic json, String what, T Function(Map<String, dynamic>) fromJson) {
  if (json is! List) return [];
  final out = <T>[];
  for (final e in json) {
    try {
      out.add(fromJson(Map<String, dynamic>.from(e as Map)));
    } catch (err) {
      Log.e('$what: skipped a damaged entry', '$err');
    }
  }
  return out;
}
