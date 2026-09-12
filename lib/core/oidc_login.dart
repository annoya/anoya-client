import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'log.dart';

/// Runs the OIDC Authorization Code + PKCE flow for a native app:
/// discovery → open the system auth browser (ASWebAuthenticationSession via
/// the `vpn/web_auth` channel) → exchange the returned code for an ID token.
/// The management service is NOT involved in the OAuth dance; it only verifies
/// the resulting ID token afterwards. No client secret (public client).
///
/// Returns the raw ID token, or throws [OidcException] on any failure.
class OidcException implements Exception {
  OidcException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _redirectUri = 'vpnclient://auth';
const _callbackScheme = 'vpnclient';
const _webAuth = MethodChannel('vpn/web_auth');

Future<String> obtainOidcIdToken(AuthProvider provider) async {
  final disco = await _discover(provider.issuer);
  final authEndpoint = disco['authorization_endpoint'] as String?;
  final tokenEndpoint = disco['token_endpoint'] as String?;
  if (authEndpoint == null || tokenEndpoint == null) {
    throw OidcException(
      'Provider discovery is missing authorization/token endpoints.',
    );
  }

  final verifier = _randomUrlToken(32);
  final challenge = _s256(verifier);
  final state = _randomUrlToken(16);
  final nonce = _randomUrlToken(16);

  final authUrl = Uri.parse(authEndpoint).replace(
    queryParameters: {
      'response_type': 'code',
      'client_id': provider.clientId,
      'redirect_uri': _redirectUri,
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'nonce': nonce,
    },
  );

  final callback = await _runWebAuth(authUrl.toString());
  final params = Uri.parse(callback).queryParameters;
  if (params['error'] != null) {
    throw OidcException(
      'Sign-in failed: ${params['error_description'] ?? params['error']}',
    );
  }
  if (params['state'] != state) {
    throw OidcException('Sign-in failed: state mismatch (possible tampering).');
  }
  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw OidcException('Sign-in failed: no authorization code returned.');
  }

  final idToken = await _exchangeCode(
    tokenEndpoint,
    provider.clientId,
    code,
    verifier,
  );
  // Sending a nonce and not checking it is worse than not sending one — it
  // implies a defense that isn't there. Reject a token minted for a different
  // sign-in attempt.
  if (idTokenNonce(idToken) != nonce) {
    throw OidcException(
      'Sign-in failed: the token does not match this sign-in attempt.',
    );
  }
  return idToken;
}

Future<Map<String, dynamic>> _discover(String issuer) async {
  final url =
      '${issuer.replaceAll(RegExp(r'/+$'), '')}/.well-known/openid-configuration';
  try {
    final res = await http.get(Uri.parse(url)).timeout(kHttpTimeout);
    if (res.statusCode ~/ 100 != 2) {
      throw OidcException('Provider discovery failed (${res.statusCode}).');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } on OidcException {
    rethrow;
  } catch (e) {
    Log.e('oidc discovery failed', '$e');
    throw OidcException('Could not reach the identity provider.');
  }
}

/// Invokes the native auth session; returns the callback URL string.
Future<String> _runWebAuth(String authUrl) async {
  try {
    final callback = await _webAuth.invokeMethod<String>('start', {
      'url': authUrl,
      'scheme': _callbackScheme,
    });
    if (callback == null || callback.isEmpty) {
      throw OidcException('Sign-in was cancelled.');
    }
    return callback;
  } on PlatformException catch (e) {
    if (e.code == 'cancelled') throw OidcException('Sign-in was cancelled.');
    throw OidcException('Sign-in failed: ${e.message ?? e.code}');
  } on MissingPluginException {
    // Every shipped platform registers the channel; this is the message for a
    // build that does not, so it never reads as a server-side failure.
    throw OidcException('Sign in with SSO is not available in this build.');
  }
}

Future<String> _exchangeCode(
  String tokenEndpoint,
  String clientId,
  String code,
  String verifier,
) async {
  final res = await http
      .post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': clientId,
          'code_verifier': verifier,
        },
      )
      .timeout(kHttpTimeout);
  if (res.statusCode ~/ 100 != 2) {
    // Status + the provider's error code only: the raw body can carry tokens
    // or account details, and this log ships in the support archive.
    String? errCode;
    try {
      errCode =
          (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {}
    Log.e(
      'oidc token exchange failed',
      '${res.statusCode}${errCode == null ? '' : ' ($errCode)'}',
    );
    throw OidcException('Token exchange failed (${res.statusCode}).');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final idToken = data['id_token'] as String?;
  if (idToken == null || idToken.isEmpty) {
    throw OidcException('Provider did not return an ID token.');
  }
  return idToken;
}

/// The `nonce` claim of an ID token, or null. The token's signature is the
/// management server's job to verify; the nonce binds the token to THIS
/// sign-in attempt, and only the client knows what it sent.
String? idTokenNonce(String idToken) {
  try {
    final parts = idToken.split('.');
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return (jsonDecode(payload) as Map<String, dynamic>)['nonce'] as String?;
  } catch (_) {
    return null;
  }
}

// PKCE helpers: base64url without padding, per RFC 7636.
String _randomUrlToken(int bytes) {
  final rnd = Random.secure();
  final b = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64UrlEncode(b).replaceAll('=', '');
}

String _s256(String verifier) => base64UrlEncode(
  sha256.convert(utf8.encode(verifier)).bytes,
).replaceAll('=', '');
