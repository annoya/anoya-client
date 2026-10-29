import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';

class ProviderRouting {
  const ProviderRouting({required this.routing, this.skipped = 0});

  final Routing routing;

  final int skipped;

  bool get isEmpty => routing.rules.isEmpty;
}

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

      final hasMatcher = entry['domain'] != null || entry['ip'] != null;
      if (!hasMatcher) {
        if (entry['inboundTag'] != null ||
            entry['port'] != null ||
            entry['protocol'] != null) {
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

ProviderRouting? parseHappRouting(String header) {
  try {
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

    final global = '${json['GlobalProxy']}'.toLowerCase() == 'true';
    final mode = global ? 'full' : 'split';
    if (rules.isEmpty) {
      return null;
    }
    return ProviderRouting(
      routing: Routing(mode: mode, rules: rules),
      skipped: skipped,
    );
  } catch (e) {
    Log.e('provider routing: unreadable happ routing', '$e');
    return null;
  }
}

String? _actionForTag(Object? tag) {
  final t = '${tag ?? ''}'.toLowerCase();
  if (t.isEmpty) return null;
  if (t.contains('block') || t.contains('reject') || t.contains('blackhole')) {
    return 'block';
  }
  if (t.contains('direct') || t.contains('bypass')) return 'direct';
  if (t.contains('dns')) return null;
  return 'proxy';
}

RoutingRule? _domainRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, values: [value], action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('domain:')) return make('domain-suffix', v.substring(7));
  if (v.startsWith('full:')) return make('domain-exact', v.substring(5));
  if (v.startsWith('keyword:')) return make('domain-keyword', v.substring(8));
  if (v.startsWith('geosite:')) return make('geosite', v.substring(8));
  if (v.startsWith('regexp:')) return make('domain-regex', v.substring(7));
  if (v.startsWith('ext:')) return null;
  return make('domain-keyword', v);
}

RoutingRule? _ipRule(String raw, String action) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  RoutingRule? make(String type, String value) {
    final r = RoutingRule(type: type, values: [value], action: action);
    return r.isValid ? r : null;
  }

  if (v.startsWith('geoip:')) return make('geoip', v.substring(6));
  if (v.startsWith('ext:')) return null;
  if (!v.contains('/') && !v.contains(':')) return make('ip-cidr', '$v/32');
  return make('ip-cidr', v);
}
