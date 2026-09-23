import 'norm_config.dart';
import 'on_demand.dart';

enum VpnStatus { disconnected, connecting, connected, error }

abstract class VpnCore {
  Future<void> load(NormConfig config);

  Future<void> connect(String locationId);

  Future<DateTime?> connectedSince() async => null;

  Future<void> disconnect();

  Future<void> reload(NormConfig config, String locationId) async =>
      throw UnsupportedError('hot reload is not supported by this core');

  Stream<VpnStatus> statusStream();

  VpnStatus get status;

  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async => false;

  Future<void> syncConfig(NormConfig config, String locationId) async {}

  Future<void> removeSystemProfile() async {}

  Future<String> lastDisconnectError() async => '';

  Future<String> urlTest(String url, Duration timeout) async =>
      'err:this build cannot test the connection';

  Future<void> setAutoConnect(bool enabled) async {}

  Future<String> proxyBytes() async => '0:0';
}
