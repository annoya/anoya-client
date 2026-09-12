import 'norm_config.dart';
import 'on_demand.dart';

/// VpnStatus is the connection lifecycle reported by a [VpnCore].
enum VpnStatus { disconnected, connecting, connected, error }

/// VpnCore is what screens and state talk to instead of the platform. The
/// engine behind it is mihomo and nothing else is planned; the interface exists
/// so the state layer can be tested against a fake tunnel, and so the platform
/// side (Network Extension, VpnService) stays behind one class.
///
/// The translation from [NormConfig] into the engine's own config lives
/// entirely inside the implementation.
abstract class VpnCore {
  /// Load a freshly fetched config bundle into the core (does not connect).
  Future<void> load(NormConfig config);

  /// Bring the tunnel up for the given location id.
  Future<void> connect(String locationId);

  /// When the current session was established, as the system recorded it —
  /// null when there is none, or when the platform cannot say.
  ///
  /// Asked rather than stamped locally because the tunnel can be up before the
  /// app is: started from the system's own VPN switch, or by an on-demand rule.
  /// A clock started when the app happened to look would count from the wrong
  /// moment, and the system has the right one.
  Future<DateTime?> connectedSince() async => null;

  /// Tear the tunnel down.
  Future<void> disconnect();

  /// Swap the running tunnel onto a new config (another location or profile)
  /// without dropping the session — the tunnel interface and OS routes stay
  /// up, so no traffic escapes during the switch. Only meaningful while
  /// connected; a fake that does not model it throws and the caller falls back
  /// to a plain sync (next connect picks the change up).
  Future<void> reload(NormConfig config, String locationId) async =>
      throw UnsupportedError('hot reload is not supported by this core');

  /// Connection status updates.
  Stream<VpnStatus> statusStream();

  /// Current status snapshot.
  VpnStatus get status;

  /// Apply system auto-connect state and report whether it ended up armed.
  /// [config]/[locationId] describe what the system should bring up when a
  /// rule matches; without them arming is refused (the OS would retry a
  /// config-less start in a loop). A platform with no such facility keeps this
  /// a no-op returning false.
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async => false;

  /// Keep the system's saved tunnel config in step with the current selection,
  /// without connecting. Called whenever the effective config changes
  /// (configuration, location, routing, refreshed servers) so an on-demand
  /// start never resurrects a stale one. No-op where not applicable.
  Future<void> syncConfig(NormConfig config, String locationId) async {}

  /// Tear down the OS-level VPN profile — the user removed their last
  /// configuration, so the app should leave nothing behind in the system's VPN
  /// settings. Recreated on the next connect.
  Future<void> removeSystemProfile() async {}

  /// Why the tunnel last stopped on its own, as the platform recorded it.
  ///
  /// Empty when there is nothing to tell — an ordinary stop, a platform too old
  /// to keep the reason, or an extension the system killed without one. Part of
  /// this seam rather than reached for directly, because a failure that only
  /// the platform knows about is exactly what a fake core has to be able to
  /// stand in for.
  Future<String> lastDisconnectError() async => '';

  /// One probe through the running tunnel: `ms:<delay>` or `err:<reason>`.
  ///
  /// Deliberately a string rather than a parsed value — the platforms carry it
  /// as one, and [ConnectionCheck.parse] is the single place that reads it.
  /// The default answer is a refusal, because a core that cannot probe must not
  /// report a healthy tunnel it never tested.
  Future<String> urlTest(String url, Duration timeout) async =>
      'err:this build cannot test the connection';

  /// Tells the platform whether it may bring the tunnel up on its own when the
  /// machine starts.
  ///
  /// Only Windows can: its tunnel is our service, started by the system with
  /// nobody logged in yet. Apple has on-demand rules for this and Android the
  /// system's own switch, so both ignore it.
  Future<void> setAutoConnect(bool enabled) async {}

  /// Bytes carried through the tunnel's outbound this session, `<up>:<down>`.
  ///
  /// Zero when there is nothing to report — no session, no platform side, or
  /// simply no traffic yet. The caller cannot tell those apart and does not
  /// need to: all three mean "ask the server yourself".
  Future<String> proxyBytes() async => '0:0';
}
