import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session persists the server URL and client token in the macOS Keychain.
///
/// The app is sandboxed, so it uses the data-protection keychain (the default):
/// a sandboxed app gets its application-identifier as an implicit
/// keychain-access-group, so no extra entitlement is needed. (The legacy
/// file-based keychain is not accessible from a sandboxed app.)
class Session {
  static const _storage = FlutterSecureStorage();
  static const _kServer = 'server_url';
  static const _kToken = 'token';

  Future<void> save({required String serverUrl, required String token}) async {
    await _storage.write(key: _kServer, value: serverUrl);
    await _storage.write(key: _kToken, value: token);
  }

  Future<String?> serverUrl() => _storage.read(key: _kServer);
  Future<String?> token() => _storage.read(key: _kToken);

  Future<bool> isLoggedIn() async => (await token()) != null;

  Future<void> clear() async {
    await _storage.delete(key: _kServer);
    await _storage.delete(key: _kToken);
  }
}
