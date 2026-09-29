import 'dart:io';

import '../l10n/l10n.dart';
import 'log.dart';
import 'mihomo_tun_config.dart';

const kMihomoDnsSchemes = {
  'udp',
  'tcp',
  'tls',
  'http',
  'https',
  'quic',
  'system',
  'dhcp',
  'rcode',
  'ts',
  'tailscale',
};

const kFallbackNameserver = 'https://1.1.1.1/dns-query';

const kFallbackBootstrap = [
  'https://1.1.1.1/dns-query',
  'https://8.8.8.8/dns-query',
  'https://9.9.9.9/dns-query',
];

const kMaxNameservers = 8;

const kDnsRespectRules = 'RULES';

class DnsResolver {
  const DnsResolver({
    required this.address,
    this.pin = '',
    this.pinIgnored = false,
  });

  final String address;

  final String pin;

  final bool pinIgnored;

  String get wire => pin.isEmpty ? address : '$address#$pin';

  String get routing => switch (pin) {
    '' => L10n.current.dnsRoutingDirect,
    kDnsRespectRules => L10n.current.dnsRoutingFollowsRules,
    _ => L10n.current.dnsRoutingThroughTunnel,
  };

  bool get viaTunnel => pin.isNotEmpty && pin != kDnsRespectRules;

  String get protocol => switch (_scheme(address)) {
    'https' || 'http' => L10n.current.dnsProtocolDoh,
    'tls' => L10n.current.dnsProtocolDot,
    'quic' => L10n.current.dnsProtocolDoq,
    'ts' || 'tailscale' => 'Tailscale',
    _ => L10n.current.dnsProtocolPlain,
  };
}

enum DnsDropReason { malformed, unknownScheme, cannotCarry, tooMany }

class DnsDrop {
  const DnsDrop(this.address, this.reason);

  final String address;
  final DnsDropReason reason;

  String get explanation => switch (reason) {
    DnsDropReason.malformed => L10n.current.dnsDropMalformed,
    DnsDropReason.unknownScheme => L10n.current.dnsDropUnknownScheme,
    DnsDropReason.cannotCarry => L10n.current.dnsDropCannotCarry,
    DnsDropReason.tooMany => L10n.current.dnsDropTooMany(kMaxNameservers),
  };
}

class DnsPlan {
  const DnsPlan({
    required this.resolvers,
    required this.bootstrap,
    required this.dropped,
    required this.usingFallback,
    required this.needsBootstrapNameserver,
  });

  final List<DnsResolver> resolvers;

  final List<String> bootstrap;

  final List<DnsDrop> dropped;

  final bool usingFallback;

  final bool needsBootstrapNameserver;
}

DnsPlan dnsPlanFor({
  required List<String> dns,
  required Set<String> outbounds,
  required bool carriesUdp,
  String fallback = kFallbackNameserver,
}) {
  final dropped = <DnsDrop>[];
  final sane = <String>[];

  for (final raw in dns) {
    final ns = raw.trim();
    if (ns.isEmpty) continue;
    final address = ns.split('#').first;
    if (address.isEmpty ||
        RegExp(r'[^\x21-\x7e]').hasMatch(address) ||
        address.contains('"') ||
        address.contains(r'\')) {
      dropped.add(DnsDrop(ns, DnsDropReason.malformed));
      continue;
    }
    final at = address.indexOf('://');
    if (at > 0 &&
        !kMihomoDnsSchemes.contains(address.substring(0, at).toLowerCase())) {
      dropped.add(DnsDrop(ns, DnsDropReason.unknownScheme));
      continue;
    }
    if (sane.contains(ns)) continue;
    if (sane.length >= kMaxNameservers) {
      dropped.add(DnsDrop(ns, DnsDropReason.tooMany));
      continue;
    }
    sane.add(ns);
  }

  final resolvers = <DnsResolver>[];
  for (final ns in sane) {
    final hash = ns.indexOf('#');
    final address = hash < 0 ? ns : ns.substring(0, hash);
    final asked = hash < 0 ? '' : ns.substring(hash + 1);
    final honoured =
        asked.isEmpty || asked == kDnsRespectRules || outbounds.contains(asked);
    final pin = honoured ? asked : '';
    if (pin.isNotEmpty && !carriesUdp && _overUdp(address)) {
      dropped.add(DnsDrop(ns, DnsDropReason.cannotCarry));
      continue;
    }
    resolvers.add(
      DnsResolver(address: address, pin: pin, pinIgnored: !honoured),
    );
  }

  final usingFallback = resolvers.isEmpty;
  final kept = usingFallback
      ? [
          DnsResolver(
            address: fallback,
            pin: outbounds.contains(kTunnelOutbound) ? kTunnelOutbound : '',
          ),
        ]
      : List<DnsResolver>.unmodifiable(resolvers);
  final bootstrap = <String>{for (final ns in sane) ns.split('#').first};
  if (bootstrap.isEmpty) {
    bootstrap.add(fallback);
    bootstrap.addAll(kFallbackBootstrap);
  }

  if (dropped.isNotEmpty) {
    Log.e(
      'dns: resolvers not used',
      dropped.take(8).map((d) => '${d.address} (${d.reason.name})').join(', '),
    );
  }

  return DnsPlan(
    resolvers: kept,
    bootstrap: List.unmodifiable(bootstrap),
    dropped: List.unmodifiable(dropped),
    usingFallback: usingFallback,
    needsBootstrapNameserver: bootstrap.any(_needsBootstrap),
  );
}

bool _overUdp(String address) {
  final s = _scheme(address);
  return s.isEmpty || s == 'udp' || s == 'quic' || s == 'dhcp';
}

String _scheme(String address) {
  final at = address.indexOf('://');
  return at < 0 ? '' : address.substring(0, at).toLowerCase();
}

bool _needsBootstrap(String address) {
  if (address == 'system') return false;
  String host;
  if (address.contains('://')) {
    final u = Uri.tryParse(address);
    if (u == null || u.scheme == 'dhcp') return false;
    host = u.host;
  } else if (InternetAddress.tryParse(address) != null) {
    return false;
  } else if (address.startsWith('[') && address.contains(']')) {
    host = address.substring(1, address.indexOf(']'));
  } else {
    host = address.split(':').first;
  }
  return host.isNotEmpty && InternetAddress.tryParse(host) == null;
}

class DnsPreset {
  const DnsPreset(this.name, this.address);

  final String name;
  final String address;

  String get note => switch (name) {
    'Quad9' => L10n.current.dnsPresetQuad9Note,
    'AdGuard' => L10n.current.dnsPresetAdGuardNote,
    _ => '',
  };
}

const kDnsPresets = [
  DnsPreset('Cloudflare', 'https://1.1.1.1/dns-query'),
  DnsPreset('Google', 'https://8.8.8.8/dns-query'),
  DnsPreset('Quad9', 'https://9.9.9.9/dns-query'),
  DnsPreset('AdGuard', 'https://94.140.14.14/dns-query'),
];

String dnsPresetName(String address) {
  for (final p in kDnsPresets) {
    if (p.address == address) return p.name;
  }
  return address;
}

String? dnsDefaultError(String address) {
  final plan = dnsPlanFor(
    dns: [address],
    outbounds: const {},
    carriesUdp: true,
  );
  if (plan.usingFallback) {
    return plan.dropped.firstOrNull?.explanation ??
        L10n.current.dnsErrorNotResolverAddress;
  }
  if (plan.needsBootstrapNameserver) {
    return L10n.current.dnsErrorAddressedByName;
  }
  return null;
}
