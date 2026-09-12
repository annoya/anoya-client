import 'dart:io';

import 'log.dart';
import 'mihomo_tun_config.dart';

/// What a configuration's resolvers become, and what happened to the ones that
/// did not make it.
///
/// This exists so the DNS screen and the engine cannot disagree. The renderer
/// used to decide all of this inline and report its refusals with a log line,
/// which meant the app could show a resolver it had already thrown away — and,
/// worse, could stay silent about having thrown it away. One plan, computed
/// once: the YAML is emitted from it, and the screen reads the same object.
///
/// Nothing here talks to the engine or the file system; it is a pure function
/// of the configuration's `dns` list plus two facts about the tunnel that will
/// carry it.

/// Resolver schemes mihomo knows (`config/config.go`, `parseNameServer`). An
/// unknown one is not skipped by the engine — it fails the *whole* config, so
/// one exotic entry in a subscription's `dns:` block would cost every server
/// and every rule. Anything with no scheme at all is fine: the engine reads it
/// as `udp://`.
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

/// What a configuration that names no usable resolver gets, unless the user
/// chose otherwise. Encrypted, and addressed by IP: a resolver named by domain
/// would itself need resolving before it could resolve anything.
const kFallbackNameserver = 'https://1.1.1.1/dns-query';

/// Resolvers used to find the proxy's own address when the configuration named
/// none of its own.
///
/// Three, where the query list gets one, and the asymmetry is the point. This
/// list resolves exactly one name — the server being connected to, which the
/// local network watches you connect to anyway — so a second and third operator
/// learn nothing they could not already see, and buy the tunnel a way up when
/// the first is blocked. The query list carries every domain the user visits,
/// and mihomo asks *all* of its entries at once (`batchExchange`), so an extra
/// entry there is an extra company reading everything. Redundancy is cheap here
/// and expensive there.
///
/// Only when the configuration brought nothing. A configuration that named its
/// own resolver gets that one and no additions: handing its provider's hostname
/// to three parties it never chose is not ours to do.
const kFallbackBootstrap = [
  'https://1.1.1.1/dns-query',
  'https://8.8.8.8/dns-query',
  'https://9.9.9.9/dns-query',
];

/// mihomo queries every resolver in the list at once and takes the first
/// answer, so a long list is latency and sockets, not redundancy. Real configs
/// name two or three; this is a ceiling on a body we do not control (ADR-005),
/// not a judgement about a reasonable one.
const kMaxNameservers = 8;

/// mihomo's keyword for "route this query the way you route traffic".
const kDnsRespectRules = 'RULES';

/// One resolver as the engine will actually use it.
class DnsResolver {
  const DnsResolver({
    required this.address,
    this.pin = '',
    this.pinIgnored = false,
  });

  /// The resolver itself, without any `#pin`.
  final String address;

  /// The outbound its queries ride, in mihomo's own vocabulary. Empty means
  /// the engine dials it directly, off the physical interface.
  final String pin;

  /// The configuration asked for an outbound this config does not define — the
  /// provider's own group names, which we replace with ours. The resolver is
  /// kept, the pin is not, and the user is told rather than left to wonder why
  /// their provider's arrangement did not take effect.
  final bool pinIgnored;

  /// What goes into the engine YAML.
  String get wire => pin.isEmpty ? address : '$address#$pin';

  /// How the resolver is reached, in words. `RULES` genuinely cannot be
  /// answered here — it depends on which rule matches the resolver's own
  /// address — and claiming either answer would be a guess.
  String get routing => switch (pin) {
    '' => 'direct',
    kDnsRespectRules => 'follows your rules',
    _ => 'through the tunnel',
  };

  /// True only when the query certainly leaves inside the tunnel. Drives the
  /// one place colour is used on the screen; the words above carry the meaning.
  bool get viaTunnel => pin.isNotEmpty && pin != kDnsRespectRules;

  /// Protocol in the reader's language rather than the scheme's. The point of
  /// the line is whether anyone between the device and the resolver can read
  /// the query, so an unencrypted resolver says so plainly.
  String get protocol => switch (_scheme(address)) {
    'https' || 'http' => 'DNS over HTTPS',
    'tls' => 'DNS over TLS',
    'quic' => 'DNS over QUIC',
    'ts' || 'tailscale' => 'Tailscale',
    _ => 'Plain, unencrypted',
  };
}

/// Why a resolver the configuration named will not be used.
enum DnsDropReason {
  /// Could not be a nameserver at all: whitespace, quotes, non-ASCII. Such a
  /// string reaches us from a body we do not control and must never be escaped
  /// into the YAML we assemble as text.
  malformed,

  /// A scheme `config.Parse` rejects. Passing it on would cost the whole
  /// document, not the entry — the tunnel simply would not start.
  unknownScheme,

  /// A plain `udp://` or `quic://` resolver pinned to an outbound with no UDP
  /// support. Not a slow query: an error on every attempt.
  cannotCarry,

  /// Past [kMaxNameservers]. Named rather than silently truncated, because a
  /// list that quietly lost its tail looks like a list that was fully applied.
  tooMany,
}

/// One resolver we are not sending, and why — in the user's language.
class DnsDrop {
  const DnsDrop(this.address, this.reason);

  final String address;
  final DnsDropReason reason;

  String get explanation => switch (reason) {
    DnsDropReason.malformed =>
      'Not a resolver address. Nothing from a subscription is put into the '
          'engine configuration unchecked.',
    DnsDropReason.unknownScheme =>
      'The engine has no scheme for this. Keeping it would have failed the '
          'whole configuration, not just this line.',
    DnsDropReason.cannotCarry =>
      'Plain DNS cannot travel through this server, and sending it outside '
          'the tunnel would show every site you visit to your network.',
    DnsDropReason.tooMany =>
      'Past the $kMaxNameservers the engine is given. It asks them all at '
          'once, so a longer list costs time without answering better.',
  };
}

/// The whole DNS decision for one configuration on one tunnel.
class DnsPlan {
  const DnsPlan({
    required this.resolvers,
    required this.bootstrap,
    required this.dropped,
    required this.usingFallback,
    required this.needsBootstrapNameserver,
  });

  /// What the engine's `nameserver:` will hold, in order.
  final List<DnsResolver> resolvers;

  /// `proxy-server-nameserver:` — the same resolvers with no pin, which is what
  /// the engine uses to resolve the proxy's own hostname. Never empty, and
  /// never pinned: a pinned entry here deadlocks the tunnel (ADR-008).
  final List<String> bootstrap;

  /// Named by the configuration and not used.
  final List<DnsDrop> dropped;

  /// The configuration named nothing usable, so [kFallbackNameserver] stands
  /// in. Worth surfacing: a user who sees Cloudflare here would otherwise
  /// assume their provider chose it.
  final bool usingFallback;

  /// A resolver addressed by hostname needs a plain-IP bootstrap, or the engine
  /// would need DNS to set up DNS.
  final bool needsBootstrapNameserver;
}

/// Computes the plan.
///
/// [outbounds] is every name the rendered config defines, so a pin can be
/// checked against something instead of trusted. [carriesUdp] is whether the
/// tunnel can carry datagrams — mihomo's `udp` is off unless a proxy says
/// otherwise, and a datagram dial through an outbound without it fails every
/// time.
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
    // An unknown pin is worse than no pin: mihomo reads it as a network
    // interface and binds the socket to a device that is not there.
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
      // Pinned to the tunnel when there is one. Unpinned, the query leaves on
      // the physical interface: the local network sees which resolver is being
      // used, and the resolver sees the queries beside the user's own address.
      // Through the tunnel it sees neither — and a network that blocks this
      // resolver, which is a plausible reason to be running a VPN at all, stops
      // mattering. Reaching the proxy does not depend on this: that is what the
      // unpinned bootstrap below is for.
      ? [
          DnsResolver(
            address: fallback,
            pin: outbounds.contains(kTunnelOutbound) ? kTunnelOutbound : '',
          ),
        ]
      : List<DnsResolver>.unmodifiable(resolvers);
  // Bootstrap comes from everything that survived sanitation, not only from
  // what we send: reaching the proxy is a separate job from answering queries,
  // and a resolver the tunnel cannot carry over the proxy is still fine for the
  // direct dial this list is for. It only needs a fallback when sanitation
  // left nothing at all — an empty block here is what deadlocks the tunnel.
  final bootstrap = <String>{for (final ns in sane) ns.split('#').first};
  if (bootstrap.isEmpty) {
    bootstrap.add(fallback);
    bootstrap.addAll(kFallbackBootstrap);
  }

  // One line, not one per entry: a hostile body can name hundreds, and the
  // screen is where the detail belongs now.
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

/// True when reaching this resolver means sending datagrams. No scheme is
/// `udp://` to the engine; QUIC and DHCP are datagrams by construction.
bool _overUdp(String address) {
  final s = _scheme(address);
  return s.isEmpty || s == 'udp' || s == 'quic' || s == 'dhcp';
}

String _scheme(String address) {
  final at = address.indexOf('://');
  return at < 0 ? '' : address.substring(0, at).toLowerCase();
}

/// True when the nameserver is addressed by hostname (https://dns.google/…)
/// rather than by IP. Understands the mihomo forms: plain IP, host:port,
/// scheme URLs, and the `system`/`dhcp://` pseudo-resolvers (which never need
/// bootstrapping).
bool _needsBootstrap(String address) {
  if (address == 'system') return false;
  String host;
  if (address.contains('://')) {
    final u = Uri.tryParse(address);
    if (u == null || u.scheme == 'dhcp') return false;
    host = u.host;
  } else if (InternetAddress.tryParse(address) != null) {
    return false; // bare IP, IPv6 colons included
  } else if (address.startsWith('[') && address.contains(']')) {
    host = address.substring(1, address.indexOf(']'));
  } else {
    host = address.split(':').first;
  }
  return host.isNotEmpty && InternetAddress.tryParse(host) == null;
}

/// One of the resolvers offered as the app's default, and what tells them apart
/// beyond the address.
class DnsPreset {
  const DnsPreset(this.name, this.address, [this.note = '']);

  final String name;
  final String address;

  /// Why someone would pick this one over the neighbours. Two of them filter,
  /// which changes what the user can reach — a fact that belongs before the
  /// choice, not after it.
  final String note;
}

/// The defaults offered without typing. All addressed by IP: a resolver named
/// by domain has to be resolved before it can resolve anything, and that first
/// step has nowhere to go.
const kDnsPresets = [
  DnsPreset('Cloudflare', 'https://1.1.1.1/dns-query'),
  DnsPreset('Google', 'https://8.8.8.8/dns-query'),
  DnsPreset(
    'Quad9',
    'https://9.9.9.9/dns-query',
    'filters known-malicious domains',
  ),
  DnsPreset(
    'AdGuard',
    'https://94.140.14.14/dns-query',
    'filters ads and trackers',
  ),
];

/// The preset's name for an address, or the address itself when it is not one
/// of ours. What the settings row shows, so a chosen preset reads as a choice
/// rather than as a URL.
String dnsPresetName(String address) {
  for (final p in kDnsPresets) {
    if (p.address == address) return p.name;
  }
  return address;
}

/// Whether a string can be used as the app's default resolver.
///
/// The same standard the renderer applies to a subscription's, for the same
/// reason — it ends up in a config we assemble as text — plus one the renderer
/// cannot enforce: a default addressed by hostname would need resolving before
/// it could resolve, and there is nothing behind it to do that.
String? dnsDefaultError(String address) {
  final plan = dnsPlanFor(
    dns: [address],
    outbounds: const {},
    carriesUdp: true,
  );
  if (plan.usingFallback) {
    return plan.dropped.firstOrNull?.explanation ?? 'Not a resolver address.';
  }
  if (plan.needsBootstrapNameserver) {
    return 'Addressed by name, so it would need resolving before it could '
        'resolve anything. Use its IP address.';
  }
  return null;
}
