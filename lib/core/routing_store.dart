import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';
import 'norm_config.dart';

/// Device-local split-tunneling rules, used only when the server does not
/// deliver a managed routing policy with the config bundle. Persisted as JSON
/// (same schema as normconfig routing) in the app-support directory.
class RoutingStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/local_routing.json');
  }

  /// Load local rules, or null when the user never configured any.
  static Future<Routing?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return null;
      return Routing.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      Log.e('routing: could not load local rules', '$e');
      return null;
    }
  }

  static Future<void> save(Routing routing) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(routing.toJson()));
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {/* ignore */}
  }
}
