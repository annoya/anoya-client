import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network_extension_core.dart';
import '../core/vpn_core.dart';

/// The active VPN core. macOS/iOS use the system Network Extension (full
/// tunnel). Other platforms (Linux/Windows) are not supported yet — their
/// core will be added behind this same [VpnCore] seam when built.
final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS) {
    return NetworkExtensionCore();
  }
  throw UnsupportedError('No VPN core for this platform yet');
});
