import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/ui.dart';
import 'l10n/l10n.dart';
import 'features/start_screen.dart';
import 'features/home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // The menu bar item must answer while the window is closed, which is
    // exactly when no screen is watching anything — so the shell holds it.
    ref.read(menuBarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesControllerProvider);
    final prefs = ref.watch(appPrefsProvider);

    // Removing the last configuration swaps home to the add screen, but any
    // pushed routes (settings, the configuration itself) would stay on top of
    // it — showing settings for something that no longer exists. Unwind to the
    // root so the user lands on "Add a connection".
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

    // The context-free accessor follows the preference, so a sentence produced
    // below the widget tree — an error, the menu bar — speaks the same language
    // as the screen that shows it.
    L10n.current = lookupAppLocalizations(prefs.language.locale);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      // Above the navigator, so it covers dialogs and sheets too — every text
      // field in the app is inside one route or another, and the rule should
      // not depend on which.
      builder: (context, child) => DismissKeyboardOnTapOutside(child: child!),
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: prefs.themeMode,
      locale: prefs.language.locale,
      home: profiles.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (profiles.hasProfiles ? const HomeScreen() : const StartScreen()),
    );
  }
}
