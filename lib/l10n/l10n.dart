import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The active translation, reachable without a [BuildContext].
///
/// Widgets read [L10nContext.l10n] so they rebuild with the locale. The layers
/// below the widgets — error descriptions, the menu bar, the tunnel status —
/// produce user-facing sentences with no context in reach, and they read
/// [L10n.current]. The app sets it from the language preference on every
/// build, so the two never disagree; before the first frame (and in tests
/// that never build an app) it is English.
class L10n {
  L10n._();

  static AppLocalizations current = lookupAppLocalizations(const Locale('en'));
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
