import 'norm_config.dart';

class CorpDomains {
  const CorpDomains({required this.domains, required this.server});

  final List<String> domains;

  final String server;

  factory CorpDomains.fromJson(Map<String, dynamic> j) => CorpDomains(
    domains: [
      for (final d in j['domains'] as List<dynamic>? ?? const [])
        if (d is String) d,
    ],
    server: j['server'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'domains': domains, 'server': server};
}

({List<String> domains, String? invalid}) parseCorpDomains(String input) {
  final out = <String>[];
  for (final raw in input.split(RegExp(r'[\s,;]+'))) {
    var d = raw.trim().toLowerCase();
    if (d.isEmpty) continue;
    if (d.startsWith('*.') || d.startsWith('+.')) d = d.substring(2);
    if (d.endsWith('.')) d = d.substring(0, d.length - 1);
    if (!RoutingRule.isValidValue('domain-suffix', d)) {
      return (domains: const [], invalid: raw.trim());
    }
    if (!out.contains(d)) out.add(d);
  }
  return (domains: out, invalid: null);
}

Routing withCorpDomains(Routing routing, List<CorpDomains> corp) {
  final domains = {for (final c in corp) ...c.domains}.toList();
  if (domains.isEmpty) return routing;
  return Routing(
    mode: routing.mode,
    rules: [
      RoutingRule(type: 'domain-suffix', values: domains, action: 'direct'),
      ...routing.rules,
    ],
    lists: routing.lists,
  );
}
