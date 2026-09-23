import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';

class JsonFileStore {
  JsonFileStore(this.filename);

  final String filename;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$filename');
  }

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

  // A scratch file per write, not a queue: a shared scratch name breaks
  // concurrent saves, and a queue lets one stalled write block all later ones.
  int _writeSeq = 0;

  Future<void> save(Object json) async {
    final f = await _file();
    final tmp = File('${f.path}.${_writeSeq++}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(json), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

List<T> decodeListLenient<T>(
  dynamic json,
  String what,
  T Function(Map<String, dynamic>) fromJson,
) {
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
