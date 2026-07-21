import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'log.dart';
import 'profile.dart';

/// Persists the list of [Profile]s and their secrets.
///
/// Profile metadata + cached locations go to `profiles.json` in the app-support
/// container (sandboxed, fine for share links / subscription URLs which are
/// bearer-style but not passwords). The self-hosted session **JWT** is a real
/// credential and lives in the Keychain, keyed by profile id.
class ProfileStore {
  static const _secure = FlutterSecureStorage();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/profiles.json');
  }

  static Future<List<Profile>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List<dynamic>;
      return list
          .map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      Log.e('profiles: load failed', '$e');
      return [];
    }
  }

  static Future<void> save(List<Profile> profiles) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }

  // --- self-hosted session token (Keychain) ---

  static Future<String?> token(String profileId) => _secure.read(key: 'token_$profileId');

  static Future<void> saveToken(String profileId, String token) =>
      _secure.write(key: 'token_$profileId', value: token);

  static Future<void> deleteToken(String profileId) => _secure.delete(key: 'token_$profileId');
}
