import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/log.dart';
import 'features/login_screen.dart';
import 'features/home_screen.dart';
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
    // Log the VPN engine version once at startup for diagnostics.
    ref.read(vpnCoreProvider).engineVersion().then((v) {
      Log.i('vpn engine: ${v ?? 'unavailable'}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
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
      home: auth.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (auth.loggedIn ? const HomeScreen() : const LoginScreen()),
    );
  }
}
