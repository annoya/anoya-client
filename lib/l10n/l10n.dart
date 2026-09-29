import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

class L10n {
  L10n._();

  static AppLocalizations current = lookupAppLocalizations(const Locale('en'));
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
