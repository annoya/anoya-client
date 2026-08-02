import 'norm_config.dart';
import 'on_demand.dart';

/// VpnStatus is the connection lifecycle reported by a [VpnCore].
enum VpnStatus { disconnected, connecting, connected, error }

/// VpnStats are best-effort live tunnel metrics. Fields are 0 when unknown.
class VpnStats {
  const VpnStats({this.bytesUp = 0, this.bytesDown = 0});
  final int bytesUp;
  final int bytesDown;
}

/// VpnCore is the client's core-abstraction seam. The app depends only on this
/// interface, never on a specific engine (mihomo). Swapping the core means
/// writing a new implementation; no screen or state code changes.
///
/// The translation from the core-agnostic [NormConfig] into the engine's native
/// config lives entirely inside the implementation.
abstract class VpnCore {
  /// Load a freshly fetched config bundle into the core (does not connect).
  Future<void> load(NormConfig config);

  /// Bring the tunnel up for the given location id.
  Future<void> connect(String locationId);

  /// Tear the tunnel down.
  Future<void> disconnect();

  /// Connection status updates.
  Stream<VpnStatus> statusStream();

  /// Best-effort live stats (may never emit).
  Stream<VpnStats> statsStream();

  /// Current status snapshot.
  VpnStatus get status;

  /// Engine version string for diagnostics (e.g. mihomo build), or null if the
  /// engine cannot be located/queried.
  Future<String?> engineVersion();

  /// Apply system auto-connect state and report whether it ended up armed.
  /// [config]/[locationId] describe what the system should bring up when a
  /// rule matches; without them arming is refused (the OS would retry a
  /// config-less start in a loop). A core with no such facility keeps this a
  /// no-op returning false.
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async =>
      false;

  /// Keep the system's saved tunnel config in step with the current selection,
  /// without connecting. Called whenever the effective config changes
  /// (configuration, location, routing, refreshed servers) so an on-demand
  /// start never resurrects a stale one. No-op where not applicable.
  Future<void> syncConfig(NormConfig config, String locationId) async {}

  /// Tear down the OS-level VPN profile — the user removed their last
  /// configuration, so the app should leave nothing behind in the system's VPN
  /// settings. Recreated on the next connect.
  Future<void> removeSystemProfile() async {}
}
