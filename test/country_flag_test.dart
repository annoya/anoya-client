import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/country_flag.dart';

void main() {
  group('what a name says about where the server is', () {
    test('an English country name', () {
      expect(flagEmoji('Albania → [🍿 YouTube без рекламы]'), '🇦🇱');
      expect(flagEmoji('Argentina'), '🇦🇷');
    });

    test('a Russian country name', () {
      expect(flagEmoji('Нидерланды'), '🇳🇱');
      expect(flagEmoji('Германия #2'), '🇩🇪');
      expect(flagEmoji('Объединённые Арабские Эмираты'), '🇦🇪');
      expect(flagEmoji('США — Нью-Йорк'), '🇺🇸');
    });

    test('a city stands for its country', () {
      expect(flagEmoji('Frankfurt 1'), '🇩🇪');
      expect(flagEmoji('Москва'), '🇷🇺');
    });

    test('the first place named wins, not the first in the dictionary', () {
      expect(flagEmoji('Germany via Netherlands'), '🇩🇪');
      expect(flagEmoji('Netherlands via Germany'), '🇳🇱');
    });

    test('the longer name at the same spot wins', () {
      expect(flagEmoji('Papua New Guinea'), '🇵🇬');
      expect(flagEmoji('Guinea-Bissau'), '🇬🇼');
      expect(flagEmoji('Северная Корея'), '🇰🇵');
      expect(flagEmoji('Южная Корея'), '🇰🇷');
    });

    test('a flag the provider put anywhere in the name is used as is', () {
      expect(flagEmoji('🇫🇮 Helsinki'), '🇫🇮');
      expect(flagEmoji('Fast [🇯🇵] node'), '🇯🇵');
    });

    test('a code is read only when it leads the name in capitals', () {
      expect(flagEmoji('DE-1'), '🇩🇪');
      expect(flagEmoji('[NL] 2'), '🇳🇱');
      expect(flagEmoji('Server de 1'), isNull);
      expect(flagEmoji('Fast DE'), isNull);
    });

    test('a capitalized word that is also a code is not a country', () {
      expect(flagEmoji('AI Studio'), isNull);
      expect(flagEmoji('YT без рекламы'), isNull);
      expect(flagEmoji('NO ADS'), isNull);
      expect(flagEmoji('Auto → [🚀 Оптимальная локация]'), isNull);
    });
  });

  group('a code handed to us', () {
    test('any ISO code, in any case', () {
      expect(flagForCode('nl'), '🇳🇱');
      expect(flagForCode('IT'), '🇮🇹');
    });

    test('something that is not a country code is no flag', () {
      expect(flagForCode(''), isNull);
      expect(flagForCode('ZZ'), isNull);
      expect(flagForCode('nl-ams-1'), isNull);
    });
  });

  test('every country the GeoIP picker offers has a flag', () {
    final countries = geoCountries();
    expect(countries.length, greaterThan(240));
    for (final (code, _) in countries) {
      expect(flagForCode(code), isNotNull, reason: code);
    }
  });
}
