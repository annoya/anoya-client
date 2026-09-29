library;

String? flagEmoji(String label) {
  final existing = _leadingFlag(label);
  if (existing != null) return existing;
  final code = _countryCode(label);
  return code == null ? null : _flagFromCode(code);
}

String stripLeadingFlag(String label) {
  final runes = label.runes.toList();
  if (runes.length >= 2 && _isRegional(runes[0]) && _isRegional(runes[1])) {
    return String.fromCharCodes(runes.sublist(2)).trimLeft();
  }
  return label;
}

String? _leadingFlag(String label) {
  final runes = label.runes.toList();
  if (runes.length >= 2 && _isRegional(runes[0]) && _isRegional(runes[1])) {
    return String.fromCharCodes([runes[0], runes[1]]);
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

String? _countryCode(String label) {
  final lower = label.toLowerCase();
  for (final e in _names.entries) {
    if (_containsWord(lower, e.key)) return e.value;
  }
  for (final tok in label.split(RegExp(r'[^A-Za-z]+'))) {
    if (tok.length == 2 && _codes.contains(tok.toUpperCase())) {
      return tok.toUpperCase();
    }
  }
  return null;
}

bool _containsWord(String haystackLower, String needleLower) => RegExp(
  '(^|[^a-z])${RegExp.escape(needleLower)}([^a-z]|\$)',
).hasMatch(haystackLower);

const Map<String, String> _names = {
  'united states': 'US',
  'usa': 'US',
  'america': 'US',
  'united kingdom': 'GB',
  'britain': 'GB',
  'england': 'GB',
  'uk': 'GB',
  'united arab emirates': 'AE',
  'emirates': 'AE',
  'dubai': 'AE',
  'south korea': 'KR',
  'korea': 'KR',
  'hong kong': 'HK',
  'netherlands': 'NL',
  'holland': 'NL',
  'amsterdam': 'NL',
  'germany': 'DE',
  'deutschland': 'DE',
  'frankfurt': 'DE',
  'france': 'FR',
  'paris': 'FR',
  'japan': 'JP',
  'tokyo': 'JP',
  'singapore': 'SG',
  'taiwan': 'TW',
  'canada': 'CA',
  'australia': 'AU',
  'sydney': 'AU',
  'russia': 'RU',
  'moscow': 'RU',
  'ukraine': 'UA',
  'sweden': 'SE',
  'stockholm': 'SE',
  'finland': 'FI',
  'helsinki': 'FI',
  'norway': 'NO',
  'denmark': 'DK',
  'switzerland': 'CH',
  'zurich': 'CH',
  'italy': 'IT',
  'milan': 'IT',
  'spain': 'ES',
  'madrid': 'ES',
  'portugal': 'PT',
  'poland': 'PL',
  'warsaw': 'PL',
  'turkey': 'TR',
  'istanbul': 'TR',
  'turkiye': 'TR',
  'india': 'IN',
  'mumbai': 'IN',
  'brazil': 'BR',
  'argentina': 'AR',
  'mexico': 'MX',
  'iran': 'IR',
  'tehran': 'IR',
  'kazakhstan': 'KZ',
  'armenia': 'AM',
  'georgia': 'GE',
  'israel': 'IL',
  'ireland': 'IE',
  'austria': 'AT',
  'vienna': 'AT',
  'belgium': 'BE',
  'romania': 'RO',
  'bulgaria': 'BG',
  'czech': 'CZ',
  'czechia': 'CZ',
  'prague': 'CZ',
  'hungary': 'HU',
  'budapest': 'HU',
  'greece': 'GR',
  'athens': 'GR',
  'indonesia': 'ID',
  'jakarta': 'ID',
  'vietnam': 'VN',
  'thailand': 'TH',
  'bangkok': 'TH',
  'malaysia': 'MY',
  'philippines': 'PH',
  'china': 'CN',
  'shanghai': 'CN',
  'south africa': 'ZA',
  'estonia': 'EE',
  'latvia': 'LV',
  'lithuania': 'LT',
  'iceland': 'IS',
  'luxembourg': 'LU',
  'moldova': 'MD',
  'serbia': 'RS',
  'croatia': 'HR',
  'cyprus': 'CY',
  'chile': 'CL',
  'new zealand': 'NZ',
};

final Set<String> _codes = _names.values.toSet();

List<(String, String)> geoCountries() {
  final byCode = <String, String>{};
  for (final e in _names.entries) {
    byCode.putIfAbsent(e.value, () => _title(e.key));
  }
  final list = byCode.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return list;
}

String _title(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
