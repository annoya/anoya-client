import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'amnezia/wg_keys.dart';
import 'json_file_store.dart';
import 'profile.dart';

class ProfileStore {
  static const _secure = FlutterSecureStorage();

  static final _store = JsonFileStore('profiles.json');

  static Future<List<Profile>> load() => _store.load(
    (j) => decodeListLenient(j, 'profiles', Profile.fromJson),
    <Profile>[],
  );

  static Future<void> save(List<Profile> profiles) =>
      _store.save(profiles.map((p) => p.toJson()).toList());

  static Future<String?> token(String profileId) =>
      _secure.read(key: 'token_$profileId');

  static Future<void> saveToken(String profileId, String token) =>
      _secure.write(key: 'token_$profileId', value: token);

  static Future<void> deleteToken(String profileId) =>
      _secure.delete(key: 'token_$profileId');

  static Future<String?> amneziaKey(String profileId) =>
      _secure.read(key: 'amnezia_key_$profileId');

  static Future<void> saveAmneziaKey(String profileId, String key) =>
      _secure.write(key: 'amnezia_key_$profileId', value: key);

  static Future<void> deleteAmneziaKey(String profileId) =>
      _secure.delete(key: 'amnezia_key_$profileId');

  static Future<String> amneziaInstallId() async {
    const key = 'amnezia_install_uuid';
    final existing = await _secure.read(key: key);
    if (existing != null && existing.length >= 32) return existing;
    final fresh = generateVlessId();
    await _secure.write(key: key, value: fresh);
    return fresh;
  }

  static final _selection = JsonFileStore('selection.json');

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
