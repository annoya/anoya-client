library;

import 'country_names.dart';

String? flagEmoji(String label) {
  final existing = _embeddedFlag(label);
  if (existing != null) return existing;
  final code = _countryCode(label);
  return code == null ? null : _flagFromCode(code);
}

String? flagForCode(String code) {
  final cc = code.trim().toUpperCase();
  return _codes.contains(cc) ? _flagFromCode(cc) : null;
}

String stripLeadingFlag(String label) {
  final runes = label.runes.toList();
  if (runes.length >= 2 && _isRegional(runes[0]) && _isRegional(runes[1])) {
    return String.fromCharCodes(runes.sublist(2)).trimLeft();
  }
  return label;
}

String? _embeddedFlag(String label) {
  final runes = label.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    if (_isRegional(runes[i]) && _isRegional(runes[i + 1])) {
      return String.fromCharCodes([runes[i], runes[i + 1]]);
    }
  }
  return null;
}

bool _isRegional(int r) => r >= 0x1F1E6 && r <= 0x1F1FF;

String _flagFromCode(String cc) {
  const base = 0x1F1E6;
  final up = cc.toUpperCase();
  return String.fromCharCodes([
    base + (up.codeUnitAt(0) - 65),
    base + (up.codeUnitAt(1) - 65),
  ]);
}

final _wordRe = RegExp(r'\p{L}+', unicode: true);

List<String> _words(String s) => [
  for (final m in _wordRe.allMatches(s.toLowerCase().replaceAll('ё', 'е')))
    m[0]!,
];

final Set<String> _codes = {for (final c in kCountries) c.$1};

final Map<String, String> _byName = () {
  final out = <String, String>{};
  void add(String name, String code) {
    final key = _words(name).join(' ');
    if (key.isNotEmpty) out.putIfAbsent(key, () => code);
  }

  for (final (code, en, ru) in kCountries) {
    add(en, code);
    add(ru, code);
  }
  kCountryAliases.forEach(add);
  return out;
}();

final int _longestName = _byName.keys.fold(
  1,
  (n, k) => k.split(' ').length > n ? k.split(' ').length : n,
);

const _ambiguousCodes = {
  'AD',
  'AI',
  'AM',
  'AS',
  'AT',
  'BE',
  'BY',
  'DO',
  'FM',
  'GG',
  'ID',
  'IN',
  'IS',
  'IT',
  'LA',
  'ME',
  'MY',
  'NO',
  'PM',
  'PS',
  'SO',
  'ST',
  'TG',
  'TO',
  'TV',
  'YT',
};

String? _countryCode(String label) {
  final words = _words(label);
  for (var i = 0; i < words.length; i++) {
    final maxLen = words.length - i < _longestName
        ? words.length - i
        : _longestName;
    for (var n = maxLen; n >= 1; n--) {
      final code = _byName[words.sublist(i, i + n).join(' ')];
      if (code != null) return code;
    }
  }
  final first = _wordRe.firstMatch(label)?[0];
  if (first == null || first.length != 2 || first != first.toUpperCase()) {
    return null;
  }
  if (!_codes.contains(first) || _ambiguousCodes.contains(first)) return null;
  return first;
}

List<(String, String)> geoCountries() =>
    [for (final (code, en, _) in kCountries) (code, en)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
