import 'dart:convert';

/// Build-time configuration for the Amnezia gateway.
///
/// None of this is derivable at runtime and none of it belongs in the
/// repository: the RSA key and the storage endpoints are Amnezia's, and the
/// identity fields are what their gateway checks before it answers at all.
/// Supply them with `--dart-define-from-file` (see `client/README.md`); a
/// build without them simply has no Amnezia support, which the UI reports
/// rather than pretending the network failed.
class AmneziaEnv {
  const AmneziaEnv._();

  static const endpoint =
      String.fromEnvironment('AGW_ENDPOINT', defaultValue: 'http://gw.amnezia.org:80/');

  /// The PKIX RSA public key, PEM, carried base64-encoded.
  ///
  /// Base64 rather than the PEM itself for two reasons, one practical and one
  /// load-bearing. Gradle mangles a `--dart-define` containing newlines, so
  /// the plain form cannot survive an Android build at all. And the exact
  /// bytes matter twice over: they encrypt the request envelope, and their
  /// SHA-512 is the key to the bypass proxy lists — so a value that a shell,
  /// a build system or an editor might reflow is a value that silently
  /// disables the censorship bypass while everything still appears to work.
  static const _publicKeyB64 = String.fromEnvironment('AGW_PUBLIC_KEY_B64');

  static String get publicKeyPem {
    if (_publicKeyB64.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(_publicKeyB64));
    } on FormatException {
      return '';
    }
  }

  /// Comma-separated bucket URLs holding the bypass proxy lists.
  static const _s3 = String.fromEnvironment('AGW_S3_ENDPOINTS');

  static List<String> get s3Endpoints => _s3
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  /// What the gateway is told this client is. It refuses anything it does not
  /// recognise, so these are Amnezia's own values, not ours — kept in build
  /// configuration precisely because they are someone else's and will have to
  /// move when their release does.
  static const clientName = String.fromEnvironment('AGW_CLIENT_NAME', defaultValue: 'AmneziaVPN');
  static const clientVersion =
      String.fromEnvironment('AGW_CLIENT_VERSION', defaultValue: '5.0.1.5');
  static const distribution =
      String.fromEnvironment('AGW_DISTRIBUTION', defaultValue: 'github');
}
