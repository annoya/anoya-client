import 'package:flutter/foundation.dart';

/// Which rule types this platform can actually enforce.
///
/// PROCESS-NAME asks the engine which local application owns a connection.
/// Only desktop can answer: on iOS and Android the tunnel runs in a sandboxed
/// extension with no view of other processes, so such a rule would silently
/// never match — worse than not offering it, because the user would believe
/// their traffic is being routed by app.
///
/// Reads [defaultTargetPlatform] rather than dart:io Platform so tests can
/// exercise both sides through `debugDefaultTargetPlatformOverride`.
bool get supportsProcessRules => switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
      _ => false,
    };

/// Whether this platform has system on-demand rules (NEOnDemandRule).
///
/// Android's counterpart is Always-on VPN — a switch the *system* owns: the
/// app can neither arm it nor reliably read it while the tunnel is down, so
/// offering our on-demand editor there would promise rules nobody will ever
/// evaluate.
bool get supportsOnDemand => switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };

/// Whether this platform's auto-start is the system's Always-on VPN switch.
bool get supportsAlwaysOn => defaultTargetPlatform == TargetPlatform.android;
