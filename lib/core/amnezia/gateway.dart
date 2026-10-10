import 'dart:async';
import 'dart:io';

import '../log.dart';
import '../profile_store.dart';
import 'agw_ffi.dart';
import 'amnezia_env.dart';

class AmneziaGateway {
  AmneziaGateway({required this.installationUuid, AgwClient? client})
    : _client = client ?? _shared;

  final String installationUuid;

  final AgwClient _client;

  static final AgwClient _shared = AgwClient(
    AgwConfig(
      endpoint: AmneziaEnv.endpoint,
      publicKeyPem: AmneziaEnv.publicKeyPem,
      s3Primary: AmneziaEnv.s3Endpoints,
      s3Fallback: AmneziaEnv.s3FallbackEndpoints,
    ),
  );

  static Future<void>? _restored;

  static void cancelRunning() => _shared.cancelAll();

  Future<AgwResponse> _post(
    String endpoint,
    Map<String, dynamic> payload, {
    required String serviceType,
    required String userCountryCode,
  }) async {
    await (_restored ??= _restoreState());
    final before = _client.state;
    final res = await _client.post(
      endpoint,
      payload,
      serviceType: serviceType,
      userCountryCode: userCountryCode,
    );
    final after = _client.state;
    if (after != before) {
      unawaited(
        ProfileStore.saveAmneziaGatewayState(after).catchError(
          (Object e) => Log.e('amnezia: gateway state not saved', '$e'),
        ),
      );
    }
    return res;
  }

  Future<void> _restoreState() async {
    if (_client.state.isNotEmpty) return;
    try {
      _client.state = await ProfileStore.amneziaGatewayState() ?? '';
    } catch (e) {
      Log.e('amnezia: gateway state not restored', '$e');
    }
  }

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

  Future<AgwResponse> accountInfo({
    required String apiKey,
    required String serviceType,
    required String userCountryCode,
    String subscriptionStatus = 'active',
  }) {
    return _post(
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

  Future<AgwResponse> config({
    required String apiKey,
    required String serviceType,
    required String serviceProtocol,
    required String userCountryCode,
    required String publicKey,
    String serverCountryCode = '',
    bool isConnectEvent = false,
  }) {
    return _post(
      'v1/config',
      {
        ..._base(),
        'user_country_code': userCountryCode,
        if (serverCountryCode.isNotEmpty)
          'server_country_code': serverCountryCode,
        'service_type': serviceType,
        'service_protocol': serviceProtocol,
        'public_key': publicKey,
        'auth_data': {'api_key': apiKey},
        if (isConnectEvent) 'is_connect_event': true,
      },
      serviceType: serviceType,
      userCountryCode: userCountryCode,
    );
  }
}
