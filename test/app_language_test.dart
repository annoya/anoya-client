import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/app_prefs.dart';

void main() {
  test('a first launch speaks the language of the system', () {
    expect(AppLanguage.ofSystem(const Locale('ru', 'RU')), AppLanguage.ru);
    expect(AppLanguage.ofSystem(const Locale('zh', 'TW')), AppLanguage.zh);
    expect(AppLanguage.ofSystem(const Locale('fr', 'CA')), AppLanguage.fr);
    expect(
      AppLanguage.ofSystem(const Locale('de')),
      AppLanguage.en,
      reason: 'a language without a translation falls back to English',
    );
  });

  testWidgets('prefs that name no language take the system one', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('es', 'MX');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    expect(AppPrefs.initial().language, AppLanguage.es);
    expect(AppPrefs.fromJson(const {}).language, AppLanguage.es);
    expect(
      AppPrefs.fromJson(const {'language': 'ru'}).language,
      AppLanguage.ru,
      reason: 'a language the user picked wins over the system',
    );
  });
}
