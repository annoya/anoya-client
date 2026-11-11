import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  test('a Russian count ending in one is not shown as 1', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    expect(ru.commonServersCount(1), '1 сервер');
    expect(ru.commonServersCount(21), '21 сервер');
    expect(ru.commonServersCount(22), '22 сервера');
    expect(ru.commonServersCount(25), '25 серверов');
    expect(ru.geositeDomainCount(101), '101 домен');
    expect(ru.commonDaysAgo(31), '31 день назад');
    expect(ru.settingsExcludedAppsCount(0), 'Нет');
  });

  test('a French zero is not shown as 1', () {
    final fr = lookupAppLocalizations(const Locale('fr'));

    expect(fr.commonServersCount(0), '0 serveur');
    expect(fr.commonServersCount(1), '1 serveur');
    expect(fr.commonServersCount(2), '2 serveurs');
  });
}
