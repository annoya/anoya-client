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
    // Held here so the menu bar keeps answering while the window is closed.
    ref.read(menuBarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesControllerProvider);
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

    // Set in build so strings made outside the widget tree follow the language.
    L10n.current = lookupAppLocalizations(prefs.language.locale);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      // Above the navigator so it also covers dialogs and sheets.
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
