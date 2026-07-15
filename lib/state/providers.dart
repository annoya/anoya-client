import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io' show Platform;

import '../api/api_client.dart';
import '../api/session.dart';
import '../core/network_extension_core.dart';
import '../core/oidc_login.dart';
import '../core/vpn_core.dart';

final sessionProvider = Provider<Session>((_) => Session());

/// The active VPN core. macOS/iOS use the system Network Extension (full
/// tunnel). Other platforms (Linux/Windows) are not supported yet — their
/// core will be added behind this same [VpnCore] seam when built.
final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS) {
    return NetworkExtensionCore();
  }
  throw UnsupportedError('No VPN core for this platform yet');
});

/// Auth state for the app shell.
class AuthState {
  const AuthState({this.loading = false, this.loggedIn = false, this.serverUrl});
  final bool loading;
  final bool loggedIn;
  final String? serverUrl;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState(loading: true);
  }

  Session get _session => ref.read(sessionProvider);

  Future<void> _init() async {
    final token = await _session.token();
    final server = await _session.serverUrl();
    state = AuthState(loggedIn: token != null, serverUrl: server);
  }

  Future<void> login(String serverUrl, String username, String password) async {
    final api = ApiClient(serverUrl);
    final result = await api.login(username, password);
    await _session.save(serverUrl: api.baseUrl, token: result.token);
    state = AuthState(loggedIn: true, serverUrl: api.baseUrl);
  }

  /// Fetch which auth methods a server offers (password + SSO providers).
  Future<AuthConfig> authConfig(String serverUrl) =>
      ApiClient(serverUrl).authConfig();

  /// Sign in via an SSO provider: run the browser OIDC flow, then exchange the
  /// ID token with the server for a session.
  Future<void> loginOIDC(String serverUrl, AuthProvider provider) async {
    final api = ApiClient(serverUrl);
    final idToken = await obtainOidcIdToken(provider);
    final result = await api.loginOIDC(provider.id, idToken);
    await _session.save(serverUrl: api.baseUrl, token: result.token);
    state = AuthState(loggedIn: true, serverUrl: api.baseUrl);
  }

  Future<void> logout(VpnCore core) async {
    try {
      await core.disconnect();
    } catch (_) {/* ignore */}
    await _session.clear();
    state = const AuthState(loggedIn: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
