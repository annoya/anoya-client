import 'dart:io';

import 'agw_ffi.dart';
import 'amnezia_env.dart';

/// The two gateway calls this app makes.
///
/// Everything else Amnezia's client can ask for — services catalogue, trials,
/// purchases, captchas, renewal links — is deliberately absent: this app
/// imports a subscription somebody already has, and an endpoint we do not call
/// is a behaviour we cannot get wrong.
class AmneziaGateway {
  AmneziaGateway({required this.installationUuid, AgwClient? client})
      : _client = client ??
            AgwClient(AgwConfig(
              endpoint: AmneziaEnv.endpoint,
              publicKeyPem: AmneziaEnv.publicKeyPem,
              s3Primary: AmneziaEnv.s3Endpoints,
            ));

  /// Stable per installation, and sent on every request. The gateway counts
  /// devices by it, so it must survive app restarts and must not be shared.
  final String installationUuid;

  final AgwClient _client;

  /// Bypass state, worth persisting between launches — see [AgwClient.state].
  String get state => _client.state;
  set state(String value) => _client.state = value;

  /// What every request carries, whatever it asks for. Empty values are
  /// dropped rather than sent blank: absent and empty are different answers to
  /// the gateway, and it is theirs to interpret.
  Map<String, dynamic> _base() => {
        'os_version': _osName,
        'app_version': AmneziaEnv.clientVersion,
        'cli_name': AmneziaEnv.clientName,
        'distribution': AmneziaEnv.distribution,
        'app_language': Platform.localeName.split(RegExp('[_-]')).first,
        'installation_uuid': installationUuid,
      }..removeWhere((_, v) => v is String && v.isEmpty);

  static String get _osName {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'linux';
  }

  /// The subscription as a whole: which locations it may use, with which
  /// protocols, how long it runs and how many devices it allows.
  Future<AgwResponse> accountInfo({
    required String apiKey,
    required String serviceType,
    required String userCountryCode,
    String subscriptionStatus = 'active',
  }) {
    return _client.post(
      'v1/account_info',
      {
        ..._base(),
        'user_country_code': userCountryCode,
        'service_type': serviceType,
        'auth_data': {'api_key': apiKey},
        'cli_version': AmneziaEnv.clientVersion,
        'subscription_status': subscriptionStatus,
      },
      serviceType: serviceType,
      userCountryCode: userCountryCode,
    );
  }

  /// One location's actual protocol config, issued against a key this device
  /// generated. The gateway hands out a new one per request — which is why a
  /// location change and a stale key both end here.
  Future<AgwResponse> config({
    required String apiKey,
    required String serviceType,
    required String serviceProtocol,
    required String userCountryCode,
    required String publicKey,
    String serverCountryCode = '',
    bool isConnectEvent = false,
  }) {
    return _client.post(
      'v1/config',
      {
        ..._base(),
        'user_country_code': userCountryCode,
        if (serverCountryCode.isNotEmpty) 'server_country_code': serverCountryCode,
        'service_type': serviceType,
        'service_protocol': serviceProtocol,
        // AWG: the client's WireGuard public key, whose private half never
        // leaves this device. VLESS: the user id the server will accept.
        'public_key': publicKey,
        'auth_data': {'api_key': apiKey},
        if (isConnectEvent) 'is_connect_event': true,
      },
      serviceType: serviceType,
      userCountryCode: userCountryCode,
    );
  }
}
