import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';

/// Routing a subscription's panel wants applied, translated into this app's
/// model.
///
/// Panels express it in whichever engine's language their template targets, so
/// this file reads the two shapes that actually arrive and neither of them is
/// ours:
///
///  - an **Xray** `routing` block, inside the JSON variant of a subscription;
///  - a **Happ** routing payload, in a `routing:` response header.
///
/// Both are translated, never adopted wholesale. Their rule sets contain
/// concepts our engine has no equivalent for — inbound tags, ports, regular
/// expressions — and a rule we cannot express is dropped rather than
/// approximated: a routing rule that does almost the right thing sends traffic
/// somewhere the user did not agree to.

/// The panel's routing plus what we had to leave behind, so the app can say so
/// instead of presenting a partial policy as complete.
class ProviderRouting {
  const ProviderRouting({required this.routing, this.skipped = 0});

  final Routing routing;

  /// Rules the source carried that this app cannot express.
  final int skipped;

  bool get isEmpty => routing.rules.isEmpty;
}

/// Reads an Xray `routing` block — the shape a panel serves to Xray-based
/// clients, and the only place some panels put their rules at all.
///
/// The body is a full Xray config (or a list of them); only its routing matters
/// here, since the servers come from the format we already read.
ProviderRouting? parseXrayRouting(String body) {
  try {
    final decoded = jsonDecode(body);
    final cfg = decoded is List
        ? (decoded.isEmpty ? null : decoded.first)
        : decoded;
    if (cfg is! Map) return null;
    final routing = cfg['routing'];
    if (routing is! Map) return null;
    final raw = routing['rules'];
    if (raw is! List) return null;

    final rules = <RoutingRule>[];
    var skipped = 0;
    String? catchAll;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final action = _actionForTag(entry['outboundTag']);

      // A rule with no matcher of its own is the default for everything that
      // fell through — it decides the direction, not a rule of its own.
      final hasMatcher = entry['domain'] != null || entry['ip'] != null;
      if (!hasMatcher) {
        // Rules keyed on an inbound, a port or a protocol describe the client's
        // own listeners. Ours has none: the engine reads a tunnel interface and
        // hijacks DNS itself, so these have nothing to apply to.
        if (entry['inboundTag'] != null || entry['port'] != null || entry['protocol'] != null) {
          continue;
        }
        if (action != null) catchAll = action;
        continue;
      }
      if (action == null) {
        skipped++;
        continue;
      }

      for (final d in (entry['domain'] as List? ?? const [])) {
        final rule = _domainRule('$d', action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
      for (final ip in (entry['ip'] as List? ?? const [])) {
        final rule = _ipRule('$ip', action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
    }

    if (rules.isEmpty) return null;
    // The catch-all is the direction: "everything else direct" is a split
    // tunnel, "everything else proxied" is a full one. Absent, assume full —
    // the safer reading, since it keeps traffic inside the tunnel.
    final mode = catchAll == 'direct' ? 'split' : 'full';
    return ProviderRouting(
      routing: Routing(mode: mode, rules: rules),
      skipped: skipped,
    );
  } catch (e) {
    Log.e('provider routing: unreadable xray routing', '$e');
    return null;
  }
}

/// Reads the `routing:` response header, whose payload is a Happ routing
/// profile: a direction plus six lists (sites and IPs for proxy, direct and
/// block).
ProviderRouting? parseHappRouting(String header) {
  try {
    // The header is a deep link: happ://routing/add/<base64 json>.
    final payload = header.trim().split('/').last;
    final json = jsonDecode(decodeLooseBase64(payload));
    if (json is! Map) return null;

    final rules = <RoutingRule>[];
    var skipped = 0;
    void addAll(String? key, String type, String action) {
      for (final v in (json[key] as List? ?? const [])) {
        final s = '$v'.trim();
        if (s.isEmpty) continue;
        final rule = type == 'domain'
            ? _domainRule(s, action)
            : _ipRule(s, action);
        if (rule == null) {
          skipped++;
        } else {
          rules.add(rule);
        }
      }
    }

    addAll('ProxySites', 'domain', 'proxy');
    addAll('ProxyIp', 'ip', 'proxy');
    addAll('DirectSites', 'domain', 'direct');
    addAll('DirectIp', 'ip', 'direct');
    addAll('BlockSites', 'domain', 'block');
    addAll('BlockIp', 'ip', 'block');

    // GlobalProxy is the direction, in the same words as ours.
    final global = '${json['GlobalProxy']}'.toLowerCase() == 'true';
    final mode = global ? 'full' : 'split';
    if (rules.isEmpty) {
      // A direction with no exceptions is still a policy — "everything through
      // the VPN" is what most panels send — but it is also what we do by
      // default, so there is nothing to show.
      return null;
    }
    return ProviderRouting(routing: Routing(mode: mode, rules: rules), skipped: skipped);
  } catch (e) {
    Log.e('provider routing: unreadable happ routing', '$e');
    return null;
  }
}

/// Reads the routing of a Clash/mihomo body: its `rules:` and the
/// `rule-providers:` those rules refer to.
///
/// Already our engine's language, so this is a transcription rather than a
/// translation — including `RULE-SET`, which mihomo supports natively.
ProviderRouting? parseClashRouting(String body) {
  final YamlMap doc;
  try {
    final parsed = loadYaml(body);
    if (parsed is! YamlMap) return null;
    doc = parsed;
  } catch (e) {
    Log.e('provider routing: unreadable clash body', '$e');
    return null;
  }
  final rules = (doc['rules'] as YamlList?)?.map((e) => '$e').toList();
  if (rules == null || rules.isEmpty) return null;
  return parseClashRules(rules, lists: _clashRuleLists(doc['rule-providers']));
}

/// Translates a `rule-providers:` block. Only remote lists survive: `file`
/// points at the publisher's own disk and `inline` carries its payload in a
/// config we did not receive.
List<RuleList> _clashRuleLists(Object? node) {
  if (node is! YamlMap) return const [];
  final out = <RuleList>[];
  node.forEach((name, spec) {
    if (spec is! YamlMap) return;
    if ('${spec['type']}' != 'http') return;
    final list = RuleList(
      name: '$name',
      url: '${spec['url'] ?? ''}',
      behavior: '${spec['behavior'] ?? ''}',
      format: spec['format'] == null ? 'yaml' : '${spec['format']}',
    );
    if (list.isValid) out.add(list);
  });
  return out;
}

/// The `rules:` half on its own, for a caller that already has the lines.
ProviderRouting? parseClashRules(List<String> lines, {List<RuleList> lists = const []}) {
  final rules = <RoutingRule>[];
  var skipped = 0;
  String? catchAll;
  for (final line in lines) {
    final parts = line.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) continue;
    final type = parts[0].toUpperCase();
    if (type == 'MATCH') {
      catchAll = _actionForTag(parts[1]);
      continue;
    }
    final ourType = switch (type) {
      'DOMAIN-SUFFIX' => 'domain-suffix',
      'DOMAIN-KEYWORD' => 'domain-keyword',
      'DOMAIN' => 'domain-exact',
      'IP-CIDR' || 'IP-CIDR6' => 'ip-cidr',
      'GEOIP' => 'geoip',
      'GEOSITE' => 'geosite',
      'DOMAIN-REGEX' => 'domain-regex',
      // Desktop-only, and the renderer drops it on platforms that cannot
      // resolve a connection's process. Dropping it *here* was the wrong place
      // to make that decision: a provider routing their game launcher lost the
      // rule on macOS too, where it works.
      'PROCESS-NAME' => 'process-name',
      // Only nameable if the body also defined where the list comes from: a
      // rule pointing at a list we cannot fetch matches nothing, which reads
      // as "not routed" rather than "broken".
      'RULE-SET' => 'rule-list',
      _ => null,
    };
    final action = parts.length >= 3 ? _actionForTag(parts[2]) : null;
    if (ourType == null || action == null) {
      skipped++;
      continue;
    }
    final rule = RoutingRule(
      type: ourType,
      value: parts[1],
      action: action,
      noResolve: parts.contains('no-resolve'),
    );
    if (rule.isValid) {
      rules.add(rule);
    } else {
      skipped++;
    }
  }
  if (rules.isEmpty) return null;
  // A rule naming a list the body never defined is not a rule we can run.
  final named = <RuleList>[];
  final usable = <RoutingRule>[];
  for (final r in rules) {
    if (r.type != 'rule-list') {
      usable.add(r);
      continue;
    }
    final list = lists.where((l) => l.name == r.value).firstOrNull;
    if (list == null) {
      skipped++;
      continue;
    }
    if (!named.contains(list)) named.add(list);
    usable.add(r);
  }
  if (usable.isEmpty) return null;
  final mode = catchAll == 'direct' ? 'split' : 'full';
  return ProviderRouting(
    routing: Routing(mode: mode, rules: usable, lists: named),
    skipped: skipped,
  );
}

/// Outbound tags are names a template author chose, so match on what they mean
/// rather than on an exact string: anything that is not recognisably direct or a
/// sink is the proxy, because that is what a panel's template routes through.
String? _actionForTag(Object? tag) {
  final t = '${tag ?? ''}'.toLowerCase();
  if (t.isEmpty) return null;
  if (t.contains('block') || t.contains('reject') || t.contains('blackhole')) return 'block';
  if (t.contains('direct') || t.contains('bypass')) return 'direct';
  if (t.contains('dns')) return null; // handled by the engine, not by routing
  return 'proxy';
}

/// Xray domain matchers. `ext:` names a file on the panel server's own disk —
/// there is no address to fetch it from, so it has no equivalent here and an
/// approximation would route traffic somewhere the user did not agree to.
RoutingRule? _domainRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, value: value, action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('domain:')) return make('domain-suffix', v.substring(7));
  if (v.startsWith('full:')) return make('domain-exact', v.substring(5));
  if (v.startsWith('keyword:')) return make('domain-keyword', v.substring(8));
  if (v.startsWith('geosite:')) return make('geosite', v.substring(8));
  if (v.startsWith('regexp:')) return make('domain-regex', v.substring(7));
  if (v.startsWith('ext:')) return null;
  // A bare value is a substring match in Xray, which is our keyword rule.
  return make('domain-keyword', v);
}

RoutingRule? _ipRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, value: value, action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('geoip:')) return make('geoip', v.substring(6));
  if (v.startsWith('ext:')) return null;
  // Xray accepts a bare address where a CIDR is meant; our rule requires the
  // prefix, and a single address is a /32.
  if (!v.contains('/') && !v.contains(':')) return make('ip-cidr', '$v/32');
  return make('ip-cidr', v);
}
