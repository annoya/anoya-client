import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/log.dart';
import '../l10n/l10n.dart';
import '../core/norm_config.dart';

// Without a ceiling, a packet-dropping firewall hangs Connect forever.
const kHttpTimeout = Duration(seconds: 15);

// Between chunks, not for the whole transfer: geo databases can take minutes.
const kDownloadStallTimeout = Duration(seconds: 30);

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

class LoginResult {
  LoginResult(this.token, this.account);
  final String token;
  final Account account;
}

class AuthProvider {
  AuthProvider({
    required this.id,
    required this.name,
    required this.issuer,
    required this.clientId,
  });
  final int id;
  final String name;
  final String issuer;
  final String clientId;

  factory AuthProvider.fromJson(Map<String, dynamic> j) => AuthProvider(
    id: j['id'] as int,
    name: j['name'] as String? ?? 'SSO',
    issuer: j['issuer'] as String? ?? '',
    clientId: j['client_id'] as String? ?? '',
  );
}

class AuthConfig {
  AuthConfig({required this.passwordLogin, required this.providers});
  final bool passwordLogin;
  final List<AuthProvider> providers;
}

class ApiClient {
  ApiClient(String baseUrl, {this.token}) : baseUrl = _normalize(baseUrl);

  final String baseUrl;
  String? token;

  static String _normalize(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  Future<LoginResult> login(String username, String password) async {
    final data = await _send(
      'POST',
      '/api/client/login',
      body: {'username': username, 'password': password},
    );
    return _loginResult(data);
  }

  static LoginResult _loginResult(Map<String, dynamic> data) => LoginResult(
    data['token'] as String,
    Account.fromJson(data['account'] as Map<String, dynamic>? ?? {}),
  );

  Future<AuthConfig> authConfig() async {
    final data = await _send('GET', '/api/client/auth-config');
    final list = (data['providers'] as List<dynamic>? ?? [])
        .map((e) => AuthProvider.fromJson(e as Map<String, dynamic>))
        .toList();
    return AuthConfig(
      passwordLogin: data['password_login'] as bool? ?? true,
      providers: list,
    );
  }

  Future<LoginResult> loginOIDC(int providerId, String idToken) async {
    final data = await _send(
      'POST',
      '/api/client/login/oidc',
      body: {'provider_id': providerId, 'id_token': idToken},
    );
    return _loginResult(data);
  }

  Future<NormConfig> fetchConfig() async {
    final data = await _send('GET', '/api/client/config', auth: true);
    return NormConfig.fromJson(data);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    Log.i('$method $uri${auth ? ' (auth)' : ''}');

    http.Response res;
    try {
      final headers = <String, String>{
        if (body != null) 'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(kHttpTimeout);
      } else {
        res = await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(kHttpTimeout);
      }
    } on TimeoutException {
      Log.e('request to $uri timed out');
      throw ApiException(0, 'timeout', L10n.current.errorApiTimeout(baseUrl));
    } on SocketException catch (e) {
      Log.e('network error reaching $uri', e);
      throw ApiException(0, 'network', L10n.current.errorApiNetwork(baseUrl));
    } on HandshakeException catch (e) {
      Log.e('TLS handshake failed for $uri', e);
      throw ApiException(0, 'tls', L10n.current.errorApiTls(baseUrl));
    } catch (e, st) {
      Log.e('request to $uri failed', e, st);
      throw ApiException(0, 'request', L10n.current.errorApiRequest(baseUrl));
    }

    Log.i('$method $path -> ${res.statusCode} (${res.body.length} bytes)');
    // Lenient: a proxy's HTML 502 must still surface as a status-coded
    // ApiException, not a FormatException.
    Map<String, dynamic> parsed;
    try {
      parsed = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (_) {
      parsed = <String, dynamic>{};
    }
    if (res.statusCode ~/ 100 != 2) {
      final err = parsed['error'] as Map<String, dynamic>?;
      final code = err?['code'] as String? ?? 'error';
      final message =
          err?['message'] as String? ?? 'request failed (${res.statusCode})';
      Log.e('$method $path rejected: $code / $message');
      throw ApiException(res.statusCode, code, message);
    }
    return parsed;
  }
}
