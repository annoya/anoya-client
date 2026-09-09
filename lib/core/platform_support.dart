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

/// Whether the platform has any auto-connect facility to speak of — ours
/// (on-demand rules) or the system's (Android's Always-on switch).
///
/// Windows has neither: no rules the system would evaluate for us, and no
/// switch to point the user at. The settings row that explains the facility is
/// left out there rather than replaced with an explanation — there is nothing
/// to explain.
bool get hasAutoConnect => switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS || TargetPlatform.android => true,
      _ => false,
    };
