import '../amnezia/vpn_key.dart';
import '../../l10n/l10n.dart';
import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'clash_config.dart';
import 'singbox_config.dart';
import 'xray_config.dart';
import 'share_link.dart';

const _maxSubscriptionChars = 4 * 1024 * 1024;

class ParsedSubscription {
  const ParsedSubscription({
    required this.locations,
    this.unsupported = const {},
    this.providers = const [],
    this.groups = const [],
    this.dns = const [],
    this.format = SubscriptionFormat.unknown,
  });

  final List<Location> locations;

  final Map<String, int> unsupported;

  final List<ProxyProvider> providers;

  final List<ProxyGroup> groups;

  final List<String> dns;

  final SubscriptionFormat format;

  int get unsupportedCount => unsupported.values.fold(0, (a, b) => a + b);

  int get total => locations.length + unsupportedCount;

  bool get hasUnsupported => unsupported.isNotEmpty;

  bool get allPlaceholders =>
      locations.isNotEmpty &&
      locations.every((l) => _isUnroutable('${l.proxy['server']}'));

  List<String> get placeholderLines => locations.map((l) => l.label).toList();

  String get unsupportedList {
    final kinds = unsupported.keys.toList()..sort();
    return kinds.join(', ');
  }
}

enum SubscriptionFormat {
  links,
  clash,
  xray,
  singbox,

  unknown;

  String get label => switch (this) {
    SubscriptionFormat.links => L10n.current.importFormatLinks,
    SubscriptionFormat.clash => L10n.current.importFormatClash,
    SubscriptionFormat.xray => L10n.current.importFormatXray,
    SubscriptionFormat.singbox => L10n.current.importFormatSingbox,
    SubscriptionFormat.unknown => L10n.current.importFormatUnknown,
  };
}

ParsedSubscription parseSubscriptionBody(String body, {String source = ''}) =>
    Log.within(source, () => _parseBody(body));

ParsedSubscription _parseBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const ParsedSubscription(locations: []);
  if (trimmed.length > _maxSubscriptionChars) {
    Log.e('subscription rejected', 'body too large (${trimmed.length} chars)');
    return const ParsedSubscription(locations: []);
  }

  final clash = parseClashProxies(trimmed);
  if (clash != null) return clash;

  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    final xray = parseXrayServers(trimmed);
    if (xray != null) return xray;
    final singbox = parseSingboxServers(trimmed);
    if (singbox != null) return singbox;
  }

  var text = trimmed;
  if (!text.contains('://')) {
    final decoded = tryDecodeLooseBase64(text);
    if (decoded != null && decoded.contains('://')) text = decoded;
  }
  final out = <Location>[];
  final unsupported = <String, int>{};
  final malformed = <String, int>{};
  for (final line in text.split(RegExp(r'[\r\n\s]+'))) {
    if (line.isEmpty) continue;
    final parsed = parseShareLink(line);
    final loc = parsed.location;
    if (loc != null) {
      out.add(loc);
      continue;
    }
    if (parsed.malformed != null) {
      malformed.update(parsed.malformed!, (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    final why = parsed.unsupported;
    if (why != null && why.length <= 24) {
      unsupported[why] = (unsupported[why] ?? 0) + 1;
    }
  }
  if (malformed.isNotEmpty) {
    final total = malformed.values.fold(0, (a, b) => a + b);
    final reasons = [
      for (final e in malformed.entries) '${e.key} ×${e.value}',
    ].join(', ');
    Log.e('subscription: $total malformed link(s) skipped', reasons);
  }
  return ParsedSubscription(
    locations: out,
    unsupported: unsupported,
    format: out.isEmpty && unsupported.isEmpty
        ? SubscriptionFormat.unknown
        : SubscriptionFormat.links,
  );
}

List<Location> parseSubscription(String body) =>
    parseSubscriptionBody(body).locations;

enum InputKind { link, amneziaKey, subscriptionUrl, subscriptionText }

class DetectedInput {
  const DetectedInput(this.kind, this.label);

  final InputKind kind;
  final String label;
}

DetectedInput? detectInput(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final scheme = t.contains('://') ? t.split('://').first.toLowerCase() : '';
  // Before the share-link check, so unsupported vpn:// formats are refused
  // here rather than misread later.
  if (scheme == 'vpn') {
    final key = parseAmneziaVpnKey(t);
    return key == null
        ? null
        : DetectedInput(
            InputKind.amneziaKey,
            L10n.current.importDetectedAmneziaKey(key.name),
          );
  }
  final singleToken = !t.contains(RegExp(r'\s'));
  if (singleToken && kShareLinkSchemes.contains(scheme)) {
    final loc = parseProxyUri(t);
    return loc == null
        ? null
        : DetectedInput(
            InputKind.link,
            L10n.current.importDetectedServer(
              loc.proxyType.toUpperCase(),
              loc.label,
            ),
          );
  }
  if (scheme == 'http' || scheme == 'https') {
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return null;
    return DetectedInput(
      InputKind.subscriptionUrl,
      L10n.current.importDetectedSubscriptionUrl(u.host),
    );
  }
  final locs = parseSubscription(t);
  if (locs.isEmpty) return null;
  return locs.length == 1
      ? DetectedInput(
          InputKind.link,
          L10n.current.importDetectedSingleServer(locs.first.label),
        )
      : DetectedInput(
          InputKind.subscriptionText,
          L10n.current.importDetectedSubscriptionText(locs.length),
        );
}

String? whyUnusable(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final first = t.split(RegExp(r'\s+')).first;
  final scheme = first.contains('://')
      ? first.split('://').first.toLowerCase()
      : '';
  final l10n = L10n.current;
  if (scheme == 'vpn') return l10n.importUnusableNotAmneziaKey;
  if (kShareLinkSchemes.contains(scheme)) {
    final parsed = parseShareLink(first);
    final why = parsed.unsupported;
    if (why != null) {
      return why.contains('+') || why.startsWith(scheme)
          ? l10n.importUnusableNotSupported(why)
          : l10n.importUnusableTransportNotSupported(scheme, why);
    }
    return l10n.importUnusableLinkUnreadable(scheme);
  }
  if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
    return l10n.importUnusableNotSupported('$scheme://');
  }
  return l10n.importUnusableNotALink;
}

bool _isUnroutable(String host) {
  final h = host.trim().toLowerCase();
  return h == '0.0.0.0' ||
      h == '127.0.0.1' ||
      h == 'localhost' ||
      h == '::' ||
      h == '::1' ||
      h.startsWith('127.');
}

class ProxyProvider {
  const ProxyProvider({required this.name, required this.url});

  final String name;
  final String url;

  bool get isValid {
    final uri = Uri.tryParse(url);
    return name.isNotEmpty &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
  }
}
