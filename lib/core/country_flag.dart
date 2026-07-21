/// Best-effort country flag for a location label.
///
/// Subscription/link remarks rarely carry a real image; at most they contain a
/// country name, an ISO code, or an emoji flag. Apple platforms (macOS/iOS)
/// render regional-indicator flag emoji natively via Apple Color Emoji, so we
/// derive the country from the label text and return the matching emoji flag.
library;

/// Returns a flag emoji for [label], or null if no country can be inferred.
/// Order: an emoji flag already present → an ISO name/alias → a bare ISO code.
String? flagEmoji(String label) {
  final existing = _leadingFlag(label);
  if (existing != null) return existing;
  final code = _countryCode(label);
  return code == null ? null : _flagFromCode(code);
}

/// [label] with a leading emoji flag removed (so it isn't shown twice next to
/// a rendered flag). Leaves non-flag labels untouched.
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
  const base = 0x1F1E6; // regional indicator symbol letter A
  final up = cc.toUpperCase();
  return String.fromCharCodes([base + (up.codeUnitAt(0) - 65), base + (up.codeUnitAt(1) - 65)]);
}

String? _countryCode(String label) {
  final lower = label.toLowerCase();
  // Multi-word / named matches first (more specific than a 2-letter token).
  for (final e in _names.entries) {
    if (_containsWord(lower, e.key)) return e.value;
  }
  // Fall back to a standalone 2-letter ISO code token (e.g. "NL-1", "us02").
  for (final tok in label.split(RegExp(r'[^A-Za-z]+'))) {
    if (tok.length == 2 && _codes.contains(tok.toUpperCase())) return tok.toUpperCase();
  }
  return null;
}

bool _containsWord(String haystackLower, String needleLower) =>
    RegExp('(^|[^a-z])${RegExp.escape(needleLower)}([^a-z]|\$)').hasMatch(haystackLower);

/// Country names + common aliases → ISO 3166-1 alpha-2. Lowercased keys.
const Map<String, String> _names = {
  'united states': 'US', 'usa': 'US', 'america': 'US',
  'united kingdom': 'GB', 'britain': 'GB', 'england': 'GB', 'uk': 'GB',
  'united arab emirates': 'AE', 'emirates': 'AE', 'dubai': 'AE',
  'south korea': 'KR', 'korea': 'KR',
  'hong kong': 'HK',
  'netherlands': 'NL', 'holland': 'NL', 'amsterdam': 'NL',
  'germany': 'DE', 'deutschland': 'DE', 'frankfurt': 'DE',
  'france': 'FR', 'paris': 'FR',
  'japan': 'JP', 'tokyo': 'JP',
  'singapore': 'SG',
  'taiwan': 'TW',
  'canada': 'CA',
  'australia': 'AU', 'sydney': 'AU',
  'russia': 'RU', 'moscow': 'RU',
  'ukraine': 'UA',
  'sweden': 'SE', 'stockholm': 'SE',
  'finland': 'FI', 'helsinki': 'FI',
  'norway': 'NO',
  'denmark': 'DK',
  'switzerland': 'CH', 'zurich': 'CH',
  'italy': 'IT', 'milan': 'IT',
  'spain': 'ES', 'madrid': 'ES',
  'portugal': 'PT',
  'poland': 'PL', 'warsaw': 'PL',
  'turkey': 'TR', 'istanbul': 'TR', 'turkiye': 'TR',
  'india': 'IN', 'mumbai': 'IN',
  'brazil': 'BR',
  'argentina': 'AR',
  'mexico': 'MX',
  'iran': 'IR', 'tehran': 'IR',
  'kazakhstan': 'KZ',
  'armenia': 'AM',
  'georgia': 'GE',
  'israel': 'IL',
  'ireland': 'IE',
  'austria': 'AT', 'vienna': 'AT',
  'belgium': 'BE',
  'romania': 'RO',
  'bulgaria': 'BG',
  'czech': 'CZ', 'czechia': 'CZ', 'prague': 'CZ',
  'hungary': 'HU', 'budapest': 'HU',
  'greece': 'GR', 'athens': 'GR',
  'indonesia': 'ID', 'jakarta': 'ID',
  'vietnam': 'VN',
  'thailand': 'TH', 'bangkok': 'TH',
  'malaysia': 'MY',
  'philippines': 'PH',
  'china': 'CN', 'shanghai': 'CN',
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

/// Valid alpha-2 codes we accept as a bare token (the value side of _names).
final Set<String> _codes = _names.values.toSet();
