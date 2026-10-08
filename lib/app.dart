import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_version.dart';
import 'core/secret_store.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'l10n/l10n.dart';
import 'features/home_screen.dart';
import 'state/cloud_sync_controller.dart';
import 'state/menu_bar_controller.dart';
import 'state/profiles_controller.dart';
import 'state/providers.dart';

class VpnApp extends ConsumerStatefulWidget {
  const VpnApp({super.key});

  @override
  ConsumerState<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends ConsumerState<VpnApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    ref.read(menuBarProvider);
    ref.read(cloudSyncProvider);
    SecretStore.instance.usingFile.addListener(_secretsInFile);
  }

  @override
  void dispose() {
    SecretStore.instance.usingFile.removeListener(_secretsInFile);
    super.dispose();
  }

  void _secretsInFile() {
    final messenger = _messenger.currentState;
    if (!SecretStore.instance.usingFile.value || messenger == null) return;
    showToastWith(messenger, L10n.current.secretsInFileNotice);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      profilesControllerProvider.select((s) => s.loading),
    );
    final prefs = ref.watch(appPrefsProvider);

    ref.listen(profilesControllerProvider.select((s) => s.hasProfiles), (
      had,
      has,
    ) {
      if (had == true && has == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _navigator.currentState;
          if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
        });
      }
    });

    L10n.current = lookupAppLocalizations(prefs.language.locale);

    return MaterialApp(
      title: kAppName,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => DismissKeyboardOnTapOutside(child: child!),
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: prefs.themeMode,
      locale: prefs.language.locale,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const HomeScreen(),
    );
  }
}
