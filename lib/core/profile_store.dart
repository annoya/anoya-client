import 'amnezia/wg_keys.dart';
import 'json_file_store.dart';
import 'profile.dart';
import 'secret_store.dart';

class ProfileStore {
  static SecretStore get _secure => SecretStore.instance;

  static final _store = JsonFileStore('profiles.json');

  static Future<List<Profile>> load() => _store.load(
    (j) => decodeListLenient(j, 'profiles', Profile.fromJson),
    <Profile>[],
  );

  static Future<void> save(List<Profile> profiles) =>
      _store.save(profiles.map((p) => p.toJson()).toList());

  static Future<String?> token(String profileId) =>
      _secure.read('token_$profileId');

  static Future<void> saveToken(String profileId, String token) =>
      _secure.write('token_$profileId', token);

  static Future<void> deleteToken(String profileId) =>
      _secure.delete('token_$profileId');

  static Future<String?> amneziaKey(String profileId) =>
      _secure.read('amnezia_key_$profileId');

  static Future<void> saveAmneziaKey(String profileId, String key) =>
      _secure.write('amnezia_key_$profileId', key);

  static Future<void> deleteAmneziaKey(String profileId) =>
      _secure.delete('amnezia_key_$profileId');

  static Future<String?> amneziaGatewayState() =>
      _secure.read('amnezia_agw_state');

  static Future<void> saveAmneziaGatewayState(String state) =>
      _secure.write('amnezia_agw_state', state);

  static Future<String> amneziaInstallId() async {
    const key = 'amnezia_install_uuid';
    final existing = await _secure.read(key);
    if (existing != null && existing.length >= 32) return existing;
    final fresh = generateVlessId();
    await _secure.write(key, fresh);
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
