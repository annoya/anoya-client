import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'amnezia/wg_keys.dart';
import 'json_file_store.dart';
import 'profile.dart';

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
    (j) => decodeListLenient(j, 'profiles', Profile.fromJson),
    <Profile>[],
  );

  static Future<void> save(List<Profile> profiles) =>
      _store.save(profiles.map((p) => p.toJson()).toList());

  // --- self-hosted session token (Keychain) ---

  static Future<String?> token(String profileId) =>
      _secure.read(key: 'token_$profileId');

  static Future<void> saveToken(String profileId, String token) =>
      _secure.write(key: 'token_$profileId', value: token);

  static Future<void> deleteToken(String profileId) =>
      _secure.delete(key: 'token_$profileId');

  // --- Amnezia subscription key + install identity (Keychain) ---

  /// The subscription's bearer credential. In the keychain rather than in
  /// `profiles.json` because that is what it is: anyone holding it can use the
  /// subscription, and it is the one field of an Amnezia configuration that
  /// must never be exported or logged.
  static Future<String?> amneziaKey(String profileId) =>
      _secure.read(key: 'amnezia_key_$profileId');

  static Future<void> saveAmneziaKey(String profileId, String key) =>
      _secure.write(key: 'amnezia_key_$profileId', value: key);

  static Future<void> deleteAmneziaKey(String profileId) =>
      _secure.delete(key: 'amnezia_key_$profileId');

  /// Identifies this installation to the gateway, which counts devices by it.
  /// Created once and kept: a new one on every launch would spend a device
  /// slot each time the app started.
  static Future<String> amneziaInstallId() async {
    const key = 'amnezia_install_uuid';
    final existing = await _secure.read(key: key);
    if (existing != null && existing.length >= 32) return existing;
    final fresh = generateVlessId();
    await _secure.write(key: key, value: fresh);
    return fresh;
  }

  // --- which configuration and server were in use ---

  /// Kept beside the profiles rather than inside them: `profiles.json` is a
  /// bare JSON array, and turning it into an object to hold two more fields
  /// would make every existing file unreadable — the profiles would be gone,
  /// not just the selection.
  static final _selection = JsonFileStore('selection.json');

  /// The last active configuration and what it was connecting through, or two
  /// nulls. Nothing is validated here: ids outlive the things they name — a
  /// server can vanish on the next refresh — so the caller checks them against
  /// what it actually loaded.
  static Future<({String? profileId, String? selectionId})> loadSelection() =>
      _selection.load(
        (j) => j is Map
            ? (
                profileId: j['profile_id'] as String?,
                selectionId: j['selection_id'] as String?,
              )
            : (profileId: null, selectionId: null),
        (profileId: null, selectionId: null),
      );

  static Future<void> saveSelection(String? profileId, String? selectionId) =>
      _selection.save({'profile_id': ?profileId, 'selection_id': ?selectionId});
}
