import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/rule_values.dart';

void main() {
  group('a pasted list', () {
    test('splits on lines, commas, spaces and semicolons', () {
      final p = parseRuleValues(
        'domain-suffix',
        'youtube.com\ngooglevideo.com, ytimg.com;youtu.be  ggpht.com\r\n',
      );

      expect(p.values, [
        'youtube.com',
        'googlevideo.com',
        'ytimg.com',
        'youtu.be',
        'ggpht.com',
      ]);
      expect(p.bad, isEmpty);
    });

    test('comments and blank lines are skipped', () {
      final p = parseRuleValues(
        'domain-suffix',
        '# YouTube\n\nyoutube.com\n   \n#ytimg.com',
      );

      expect(p.values, ['youtube.com']);
      expect(p.bad, isEmpty);
    });

    test('each line is tidied before it is judged', () {
      final p = parseRuleValues(
        'domain-suffix',
        'https://www.youtube.com/watch?v=x\n'
            '*.ytimg.com\n'
            '+.googlevideo.com\n'
            '.ggpht.com\n'
            'YouTu.be.\n'
            'music.youtube.com:443\n'
            'www.example.org',
      );

      expect(p.values, [
        'youtube.com',
        'ytimg.com',
        'googlevideo.com',
        'ggpht.com',
        'youtu.be',
        'music.youtube.com',
        'www.example.org',
      ], reason: 'www. is dropped only from a pasted link');
    });

    test('an exact-domain rule keeps www. even from a link', () {
      expect(
        parseRuleValues('domain-exact', 'https://www.youtube.com/').values,
        ['www.youtube.com'],
      );
    });

    test('duplicates are dropped and counted, after tidying', () {
      final p = parseRuleValues(
        'domain-suffix',
        'youtube.com\nYouTube.com\n*.youtube.com\nytimg.com',
      );

      expect(p.values, ['youtube.com', 'ytimg.com']);
      expect(p.duplicates, 2);
    });
  });

  group('domains and addresses in one list', () {
    test('a domain rule takes the addresses along as ip-cidr', () {
      final p = parseRuleValues(
        'domain-suffix',
        'discord.com\n162.159.128.0/19\n2606:4700::/32\n8.8.8.8\n'
            '2001:db8::1',
      );

      expect(p.values, ['discord.com']);
      expect(p.companionType, 'ip-cidr');
      expect(p.companion, [
        '162.159.128.0/19',
        '2606:4700::/32',
        '8.8.8.8/32',
        '2001:db8::1/128',
      ], reason: 'a bare address is a /32 or a /128');
    });

    test('an ip-cidr rule takes the domains along as domain-suffix', () {
      final p = parseRuleValues('ip-cidr', '10.0.0.0/8\ncorp.example');

      expect(p.values, ['10.0.0.0/8']);
      expect(p.companionType, 'domain-suffix');
      expect(p.companion, ['corp.example']);
    });

    test('no companion when the list is all one kind', () {
      final p = parseRuleValues('domain-suffix', 'a.com\nb.com');

      expect(p.companionType, isNull);
      expect(p.companion, isEmpty);
    });
  });

  group('lines that are not values', () {
    test('are reported with their line, and do not stop the rest', () {
      final p = parseRuleValues(
        'domain-suffix',
        'youtube.com\nyoutube_com\n300.12.4.0/24\n10.0.0.0/33\nytimg.com',
      );

      expect(p.values, ['youtube.com', 'ytimg.com']);
      expect(
        [for (final b in p.bad) (b.line, b.text, b.kind)],
        [
          (2, 'youtube_com', BadValueKind.domain),
          (3, '300.12.4.0/24', BadValueKind.address),
          (4, '10.0.0.0/33', BadValueKind.address),
        ],
      );
    });

    test('a numeric last label is not a domain', () {
      expect(parseRuleValues('domain-suffix', '1.2.3').values, isEmpty);
    });
  });

  group('types read line by line', () {
    test('a pattern is read as written, one per line', () {
      final p = parseRuleValues(
        'domain-regex',
        r'^ads\.(a|b)\.com$'
            '\n'
            r'^yt[0-9]+\.',
      );

      expect(p.values, [r'^ads\.(a|b)\.com$', r'^yt[0-9]+\.']);
    });

    test('a pattern with a comma is refused: it would split the rule line', () {
      final p = parseRuleValues('domain-regex', r'^yt[0-9]{1,3}\.');

      expect(p.values, isEmpty);
      expect(p.bad.single.kind, BadValueKind.other);
    });

    test('a process name may hold a space', () {
      final p = parseRuleValues('process-name', 'Google Chrome\nSlack');

      expect(p.values, ['Google Chrome', 'Slack']);
      expect(p.companionType, isNull);
    });

    test('keywords are lowered and split like domains', () {
      expect(parseRuleValues('domain-keyword', 'Jira, confluence').values, [
        'jira',
        'confluence',
      ]);
    });
  });
}
