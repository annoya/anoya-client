import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/log.dart';
import 'features/start_screen.dart';
import 'features/home_screen.dart';
import 'state/profiles_controller.dart';
import 'state/providers.dart';

class VpnApp extends ConsumerStatefulWidget {
  const VpnApp({super.key});

  @override
  ConsumerState<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends ConsumerState<VpnApp> {
  @override
  void initState() {
    super.initState();
    ref.read(vpnCoreProvider).engineVersion().then((v) {
      Log.i('vpn engine: ${v ?? 'unavailable'}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesControllerProvider);
    return MaterialApp(
      title: 'VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F7CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: profiles.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (profiles.hasProfiles ? const HomeScreen() : const StartScreen()),
    );
  }
}
