import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/dns_plan.dart';
import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/features/dns_screen.dart';
import 'package:vpn_client/state/profiles_controller.dart';
import 'package:vpn_client/l10n/l10n.dart';

/// What the user can find out about their resolvers.
///
/// The screen exists because refusing a resolver used to be a log line: a
/// configuration could lose the DNS its provider chose and look untouched. So
/// the load-bearing test here is not that the screen renders — it is that the
/// screen cannot describe a configuration the engine never received.
void main() {
  Location server({bool udp = true}) => Location(
    id: 'l1',
    label: 'Germany',
    proxy: {
      'type': 'vless',
      'server': 'de.example',
      'port': 443,
      'uuid': 'u',
      'network': 'tcp',
      'tls': true,
      if (udp) 'udp': true,
    },
  );

  Profile profile(
    List<String> dns, {
    ProfileType type = ProfileType.subscription,
    bool udp = true,
  }) => Profile(
    id: 'p1',
    type: type,
    name: 'Config',
    locations: [server(udp: udp)],
    subscriptionUrl: type == ProfileType.subscription
        ? 'https://panel.example/s/a'
        : null,
    serverUrl: type == ProfileType.selfhosted ? 'https://vpn.example' : null,
    dns: dns,
  );

  Future<void> pump(WidgetTester tester, Profile p) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesControllerProvider.overrideWith(() => _FixedProfiles([p])),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DnsScreen(profile: p),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a resolver is named with its protocol, routing and origin', (
    tester,
  ) async {
    await pump(tester, profile(['https://dns.quad9.net/dns-query#PROXY']));
    expect(find.text('https://dns.quad9.net/dns-query'), findsOneWidget);
    expect(find.text('through the tunnel'), findsOneWidget);
    expect(
      find.text('DNS over HTTPS · from your subscription'),
      findsOneWidget,
    );
  });

  testWidgets('a plaintext resolver says so, because that is the point', (
    tester,
  ) async {
    // "udp://" tells the reader nothing; "anyone on this network can read it"
    // is the fact the line exists to carry.
    await pump(tester, profile(['77.88.8.8']));
    expect(
      find.text('Plain, unencrypted · from your subscription'),
      findsOneWidget,
    );
    expect(find.text('direct'), findsOneWidget);
  });

  testWidgets('the app default is labelled as ours, not passed off as theirs', (
    tester,
  ) async {
    await pump(tester, profile(const []));
    expect(find.text('DNS over HTTPS · app default'), findsOneWidget);
    expect(find.textContaining('names no resolver of its own'), findsOneWidget);
  });

  group('what we refused, and why', () {
    testWidgets('a scheme the engine rejects is shown with its reason', (
      tester,
    ) async {
      await pump(
        tester,
        profile(['h3://dns.google/dns-query', 'tls://9.9.9.9']),
      );
      expect(find.text('DROPPED'), findsOneWidget);
      expect(find.text('h3://dns.google/dns-query'), findsOneWidget);
      expect(
        find.textContaining('failed the whole configuration'),
        findsOneWidget,
      );
      // And the survivor is still in force: one bad line costs one line.
      expect(find.text('tls://9.9.9.9'), findsOneWidget);
    });

    testWidgets(
      'a resolver the tunnel cannot carry names the tunnel, not the scheme',
      (tester) async {
        await pump(tester, profile(['1.1.1.1#PROXY'], udp: false));
        expect(
          find.textContaining('cannot travel through this server'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'nothing refused means no section — an empty one teaches people not to look',
      (tester) async {
        await pump(tester, profile(['tls://9.9.9.9']));
        expect(find.text('DROPPED'), findsNothing);
      },
    );
  });

  group('the app default', () {
    test('reaches the tunnel, not the local network', () {
      // Unpinned it would leave on the physical interface: the network sees
      // which resolver this device trusts, the resolver sees the queries next
      // to the user's own address, and a network that blocks it — a plausible
      // reason to be running a VPN — takes DNS down with it.
      final shape = engineShape(server());
      final plan = dnsPlanFor(
        dns: const [],
        outbounds: shape.outbounds,
        carriesUdp: true,
      );
      expect(plan.usingFallback, isTrue);
      expect(plan.resolvers.single.wire, 'https://1.1.1.1/dns-query#PROXY');
    });

    test(
      'reaching the proxy gets more than one operator, and the queries do not',
      () {
        // The bootstrap resolves one hostname the local network already watched
        // us dial, so a second and third operator learn nothing new and buy a way
        // up when the first is blocked. The query list carries every domain and
        // mihomo asks all of its entries at once, so an extra entry there is an
        // extra company reading everything.
        final shape = engineShape(server());
        final plan = dnsPlanFor(
          dns: const [],
          outbounds: shape.outbounds,
          carriesUdp: true,
        );
        expect(plan.resolvers, hasLength(1));
        expect(plan.bootstrap, hasLength(greaterThan(1)));
        expect(
          plan.bootstrap.every((b) => !b.contains('#')),
          isTrue,
          reason: 'a pin here is what deadlocked the tunnel',
        );
      },
    );

    test(
      'a configuration with its own resolver gets no company it did not pick',
      () {
        final shape = engineShape(server());
        final plan = dnsPlanFor(
          dns: const ['tls://dns.quad9.net'],
          outbounds: shape.outbounds,
          carriesUdp: true,
        );
        expect(
          plan.bootstrap,
          ['tls://dns.quad9.net'],
          reason:
              'handing its provider’s hostname to three parties it never '
              'chose is not ours to do',
        );
      },
    );

    test('the user’s choice is what stands in', () {
      final shape = engineShape(server());
      final plan = dnsPlanFor(
        dns: const [],
        outbounds: shape.outbounds,
        carriesUdp: true,
        fallback: 'https://9.9.9.9/dns-query',
      );
      expect(plan.resolvers.single.address, 'https://9.9.9.9/dns-query');
    });

    test(
      'a default addressed by name is refused, having nothing to resolve it',
      () {
        expect(
          dnsDefaultError('https://dns.google/dns-query'),
          contains('Use its IP address'),
        );
        expect(dnsDefaultError('not a resolver'), isNotNull);
        expect(dnsDefaultError('https://8.8.8.8/dns-query'), isNull);
      },
    );
  });

  group('a server whose settings have not been issued yet', () {
    // Amnezia hands out a server on request (ADR-009), so its locations are
    // real and pickable while still carrying nothing. Every screen that asks
    // what the engine would get meets them, and each one that asked directly
    // used to throw — the configuration screen, then the routing screen. The
    // answer belongs here, once, rather than in a guard per caller.
    final placeholder = Location(
      id: 'amnezia_de_awg',
      label: 'Germany',
      proxy: const {},
    );

    test('has an empty shape rather than no answer', () {
      final shape = engineShape(placeholder);
      expect(shape.outbounds, {'DIRECT', 'REJECT'});
      expect(
        shape.carriesUdp,
        isFalse,
        reason: 'there is no outbound yet to carry anything',
      );
    });

    test('so does a group any of whose members is one', () {
      const group = ProxyGroup(
        name: 'auto',
        type: 'url-test',
        members: ['a', 'b'],
      );
      final shape = engineShape(
        placeholder,
        group: group,
        members: [server(), placeholder],
      );
      expect(shape.outbounds, {'DIRECT', 'REJECT'});
    });

    test('and the resolvers it would use are describable', () {
      // What the DNS screen shows before anything is issued: the configuration
      // still names resolvers, and none of them can be pinned to a tunnel that
      // does not exist.
      final plan = dnsPlanFor(
        dns: const ['tls://dns.quad9.net#PROXY'],
        outbounds: engineShape(placeholder).outbounds,
        carriesUdp: false,
      );
      expect(plan.resolvers.single.address, 'tls://dns.quad9.net');
      expect(plan.resolvers.single.viaTunnel, isFalse);
    });

    test('but the renderer still refuses to run one', () {
      // Leniency here would produce a config with nowhere to send traffic.
      expect(() => mihomoTunConfigYaml(placeholder), throwsStateError);
    });
  });

  test('the screen and the engine read the same decision', () {
    // The contract that makes the screen trustworthy. Both sides are asked for
    // the same configuration and must agree resolver for resolver — if the
    // renderer ever starts deciding on its own again, this fails.
    const dns = [
      'https://dns.quad9.net/dns-query#PROXY',
      'h3://dns.google/dns-query',
      'tls://dns.google#🚀 Auto',
      '9.9.9.9',
    ];
    final loc = server();
    final shape = engineShape(loc);
    final plan = dnsPlanFor(
      dns: dns,
      outbounds: shape.outbounds,
      carriesUdp: shape.carriesUdp,
    );
    final doc = loadYaml(mihomoTunConfigYaml(loc, dns: dns)) as YamlMap;
    final block = doc['dns'] as YamlMap;

    expect(
      (block['nameserver'] as YamlList).map((e) => '$e'),
      plan.resolvers.map((r) => r.wire),
    );
    expect(
      (block['proxy-server-nameserver'] as YamlList).map((e) => '$e'),
      plan.bootstrap,
    );
    expect(
      plan.dropped.map((d) => d.reason),
      [DnsDropReason.unknownScheme],
      reason:
          'the unknown scheme is dropped; the unknown pin only loses its pin',
    );
    expect(
      plan.resolvers
          .firstWhere((r) => r.address == 'tls://dns.google')
          .pinIgnored,
      isTrue,
    );
  });
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles);
  final List<Profile> profiles;

  @override
  ProfilesState build() =>
      ProfilesState(profiles: profiles, activeId: profiles.first.id);
}
