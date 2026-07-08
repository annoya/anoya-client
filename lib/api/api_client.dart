import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/log.dart';
import '../core/norm_config.dart';

/// ApiException carries the management service's error envelope.
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

/// ApiClient talks to one management service's client API.
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
    return LoginResult(
      data['token'] as String,
      Account.fromJson(data['account'] as Map<String, dynamic>? ?? {}),
    );
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
        res = await http.get(uri, headers: headers);
      } else {
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
      }
    } on SocketException catch (e) {
      Log.e('network error reaching $uri', e);
      throw ApiException(0, 'network', 'Cannot reach $baseUrl — check the address/port and that the server is up.');
    } on HandshakeException catch (e) {
      Log.e('TLS handshake failed for $uri', e);
      throw ApiException(0, 'tls',
          'TLS error talking to $baseUrl. If the server runs plain HTTP, enter the address with "http://".');
    } catch (e, st) {
      Log.e('request to $uri failed', e, st);
      throw ApiException(0, 'request', 'Request failed: $e');
    }

    Log.i('$method $path -> ${res.statusCode} (${res.body.length} bytes)');
    final parsed = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic> : <String, dynamic>{};
    if (res.statusCode ~/ 100 != 2) {
      final err = parsed['error'] as Map<String, dynamic>?;
      final code = err?['code'] as String? ?? 'error';
      final message = err?['message'] as String? ?? 'request failed (${res.statusCode})';
      Log.e('$method $path rejected: $code / $message');
      throw ApiException(res.statusCode, code, message);
    }
    return parsed;
  }
}
