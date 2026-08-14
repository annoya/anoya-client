
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'profile.dart';
import 'json_file_store.dart';

/// Persists the list of [Profile]s and their secrets.
///
/// Profile metadata + cached locations go to `profiles.json` in the app-support
/// container (sandboxed, fine for share links / subscription URLs which are
/// bearer-style but not passwords). The self-hosted session **JWT** is a real
/// credential and lives in the Keychain, keyed by profile id.
class ProfileStore {
  static const _secure = FlutterSecureStorage();

  static final _store = JsonFileStore('profiles.json');

  static Future<List<Profile>> load() => _store.load(
      (j) => decodeListLenient(j, 'profiles', Profile.fromJson), <Profile>[]);

  static Future<void> save(List<Profile> profiles) =>
      _store.save(profiles.map((p) => p.toJson()).toList());

  // --- self-hosted session token (Keychain) ---

  static Future<String?> token(String profileId) => _secure.read(key: 'token_$profileId');

  static Future<void> saveToken(String profileId, String token) =>
      _secure.write(key: 'token_$profileId', value: token);

  static Future<void> deleteToken(String profileId) => _secure.delete(key: 'token_$profileId');
}
