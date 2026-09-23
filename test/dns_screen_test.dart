import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/dns_plan.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/dns_screen.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/l10n/l10n.dart';

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
      final plan = dnsPlanFor(
        dns: const ['tls://dns.quad9.net#PROXY'],
        outbounds: engineShape(placeholder).outbounds,
        carriesUdp: false,
      );
      expect(plan.resolvers.single.address, 'tls://dns.quad9.net');
      expect(plan.resolvers.single.viaTunnel, isFalse);
    });

    test('but the renderer still refuses to run one', () {
      expect(() => mihomoTunConfigYaml(placeholder), throwsStateError);
    });
  });

  test('the screen and the engine read the same decision', () {
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
