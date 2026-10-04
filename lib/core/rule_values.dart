import 'dart:io';

import 'norm_config.dart';

enum BadValueKind { domain, address, other }

class BadValue {
  const BadValue(this.line, this.text, this.kind);

  final int line;
  final String text;
  final BadValueKind kind;
}

class ParsedRuleValues {
  const ParsedRuleValues({
    this.values = const [],
    this.companionType,
    this.companion = const [],
    this.duplicates = 0,
    this.bad = const [],
  });

  final List<String> values;

  final String? companionType;
  final List<String> companion;
  final int duplicates;
  final List<BadValue> bad;

  bool get isEmpty => values.isEmpty && companion.isEmpty;
}

bool takesTextValues(String type) =>
    type != 'geoip' && type != 'geosite' && type != 'rule-list';

bool _splitsOnSpaces(String type) =>
    type == 'domain-suffix' ||
    type == 'domain-exact' ||
    type == 'domain-keyword' ||
    type == 'ip-cidr';

String? companionTypeFor(String type) => switch (type) {
  'domain-suffix' || 'domain-exact' => 'ip-cidr',
  'ip-cidr' => 'domain-suffix',
  _ => null,
};

ParsedRuleValues parseRuleValues(String type, String text) {
  final companionType = companionTypeFor(type);
  final values = <String>{};
  final companion = <String>{};
  final bad = <BadValue>[];
  var duplicates = 0;

  void add(Set<String> into, String v) {
    if (values.contains(v) || companion.contains(v)) {
      duplicates++;
    } else {
      into.add(v);
    }
  }

  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final tokens = _splitsOnSpaces(type)
        ? line.split(RegExp(r'[\s,;]+')).where((t) => t.isNotEmpty)
        : [line];
    for (final token in tokens) {
      if (companionType != null) {
        final host = _host(token);
        final cidr = normalizeCidr(host.host);
        if (cidr != null) {
          add(type == 'ip-cidr' ? values : companion, cidr);
          continue;
        }
        final domainType = type == 'ip-cidr' ? companionType : type;
        final domain = _domain(host, stripWww: domainType == 'domain-suffix');
        if (domain != null) {
          add(type == 'ip-cidr' ? companion : values, domain);
          continue;
        }
        bad.add(
          BadValue(
            i + 1,
            token,
            _looksNumeric(host.host)
                ? BadValueKind.address
                : BadValueKind.domain,
          ),
        );
        continue;
      }
      final v = switch (type) {
        'domain-keyword' => token.toLowerCase(),
        _ => token,
      };
      if (RoutingRule.isValidValue(type, v)) {
        add(values, v);
      } else {
        bad.add(BadValue(i + 1, token, BadValueKind.other));
      }
    }
  }

  return ParsedRuleValues(
    values: values.toList(),
    companionType: companion.isEmpty ? null : companionType,
    companion: companion.toList(),
    duplicates: duplicates,
    bad: bad,
  );
}

String? normalizeCidr(String token) {
  final slash = token.indexOf('/');
  final addr = slash < 0 ? token : token.substring(0, slash);
  final ip = InternetAddress.tryParse(addr);
  if (ip == null) return null;
  final bits = ip.type == InternetAddressType.IPv4 ? 32 : 128;
  if (slash < 0) return '${addr.toLowerCase()}/$bits';
  final prefix = int.tryParse(token.substring(slash + 1));
  if (prefix == null || prefix < 0 || prefix > bits) return null;
  return '${addr.toLowerCase()}/$prefix';
}

({String host, bool link}) _host(String token) {
  final t = token.trim();
  if (t.contains('://')) {
    final uri = Uri.tryParse(t);
    if (uri != null && uri.host.isNotEmpty) return (host: uri.host, link: true);
  }
  if (RegExp(r'^[0-9a-fA-F:.]+(/\d+)?$').hasMatch(t) &&
      (t.contains(':') || t.contains('/'))) {
    return (host: t, link: false);
  }
  var h = t;
  final slash = h.indexOf('/');
  if (slash >= 0) h = h.substring(0, slash);
  h = h.replaceFirst(RegExp(r':\d+$'), '');
  return (host: h, link: false);
}

String? _domain(({String host, bool link}) h, {required bool stripWww}) {
  var d = h.host.toLowerCase();
  for (final prefix in const ['*.', '+.', '.']) {
    if (d.startsWith(prefix)) {
      d = d.substring(prefix.length);
      break;
    }
  }
  if (d.endsWith('.')) d = d.substring(0, d.length - 1);
  if (h.link && stripWww && d.startsWith('www.')) d = d.substring(4);
  final labels = d.split('.');
  if (!RegExp(r'[a-z]').hasMatch(labels.last)) return null;
  return RoutingRule.isValidValue('domain-suffix', d) ? d : null;
}

bool _looksNumeric(String s) => RegExp(r'^[0-9a-fA-F:./]+$').hasMatch(s);
