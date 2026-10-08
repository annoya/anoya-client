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

String agoLabel(AppLocalizations l10n, DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  return d.inDays > 0
      ? l10n.commonDaysAgo(d.inDays)
      : d.inHours > 0
      ? l10n.commonHoursAgo(d.inHours)
      : d.inMinutes > 0
      ? l10n.commonMinutesAgo(d.inMinutes)
      : l10n.commonJustNow;
}
