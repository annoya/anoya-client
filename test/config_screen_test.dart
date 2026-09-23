import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/amnezia/amnezia_account.dart';
import 'package:vpn_client/core/device_identity.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/rule_list_store.dart';
import 'package:vpn_client/core/subscription_info.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/ui.dart';
import 'package:vpn_client/state/provider_rule_lists.dart';
import 'package:vpn_client/features/config/config_screen.dart';
import 'package:vpn_client/l10n/l10n.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';

void main() {
  Profile profile(
    ProfileType type, {
    Account? account,
    Routing? routing,
    List<String> dns = const [],
  }) => Profile(
    id: 'p1',
    type: type,
    name: 'Config',
    locations: [
      Location(
        id: 'l1',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.2.3.4'},
      ),
    ],
    serverUrl: type == ProfileType.selfhosted ? 'https://vpn.example' : null,
    subscriptionUrl: type == ProfileType.subscription
        ? 'https://panel.example/s/a'
        : null,
    account: account,
    routing: routing,
    dns: dns,
    refreshedAt: DateTime.now(),
  );

  Future<void> pump(
    WidgetTester tester,
    Profile p, {
    List<RuleListStatus>? lists,
    Future<void> Function(bool)? onSetLists,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(
            () => _FixedProfiles([p], onSetLists: onSetLists),
          ),
          if (lists != null)
            providerRuleListsProvider.overrideWith((ref, id) async => lists),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConfigScreen(profileId: 'p1'),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openRouting(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Routing'), 200);
    await tester.tap(find.text('Routing'));
    await tester.pumpAndSettle();
  }

  // The buttons sit at the bottom of a lazy list, so they have to be scrolled
  // into existence before they can be measured.
  Future<void> expectFullWidthButtons(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Remove configuration'), 200);
    await tester.pump();
    final outer = tester.getSize(find.byType(PageBody).first).width;
    final content = outer < kMaxContentWidth ? outer : kMaxContentWidth;
    final buttons = find.byType(OutlinedButton);
    expect(buttons, findsWidgets);
    for (var i = 0; i < tester.widgetList(buttons).length; i++) {
      final w = tester.getSize(buttons.at(i)).width;
      expect(
        w,
        closeTo(content - 2 * kGutter, 1),
        reason: 'button $i is ${w}pt wide, content is ${content}pt',
      );
    }
  }

  testWidgets('a link shows a header, routing and the actions — nothing else', (
    tester,
  ) async {
    await pump(tester, profile(ProfileType.link));
    expect(find.text('Single server'), findsOneWidget);
    expect(
      find.text('Source'),
      findsNothing,
      reason: 'a link has no origin to re-ask',
    );
    expect(find.text('Last refreshed'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Remove configuration'), findsOneWidget);
    await expectFullWidthButtons(tester);
  });

  testWidgets('a subscription shows its source and refresh, but no account', (
    tester,
  ) async {
    await pump(tester, profile(ProfileType.subscription));
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Last refreshed'), findsOneWidget);
    expect(
      find.text('Account'),
      findsNothing,
      reason: 'a panel never tells us an account state (ADR-005)',
    );
    expect(
      find.text('THIS DEVICE'),
      findsNothing,
      reason: 'not until the panel says it counts devices',
    );
    await expectFullWidthButtons(tester);
  });

  testWidgets('the id the subscription counts this device by can be copied', (
    tester,
  ) async {
    DeviceIdentityStore.debugCache(
      const DeviceIdentity(
        hwid: '7f3a9c21e4b84a2c9d0f1b3e5a6c5d0146',
        os: 'macos',
        osVersion: '15.0',
        model: 'MacBook Pro',
      ),
    );
    addTearDown(() => DeviceIdentityStore.debugCache(null));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, profile(ProfileType.subscription).copyWithDeviceLimit());
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Device id'), 200);

    expect(find.text('7f3a9c21e4b8…6c5d0146'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();
    expect(copied, '7f3a9c21e4b84a2c9d0f1b3e5a6c5d0146');
  });

  group('the routing row', () {
    testWidgets('carries both facts the sections it replaced used to show', (
      tester,
    ) async {
      await pump(
        tester,
        profile(
          ProfileType.subscription,
          dns: ['https://dns.quad9.net/dns-query#PROXY'],
        ),
      );
      await tester.scrollUntilVisible(find.text('Routing'), 200);
      expect(
        find.text(
          'Off · everything through the VPN · DNS from your subscription',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a refusal stays on the configuration screen, not behind a tap',
      (tester) async {
        await pump(
          tester,
          profile(
            ProfileType.subscription,
            dns: ['h3://dns.google/dns-query', 'tls://9.9.9.9'],
          ),
        );
        await tester.scrollUntilVisible(find.text('Routing'), 200);
        expect(find.textContaining('DNS: 1 refused'), findsOneWidget);
      },
    );

    testWidgets('a link says the DNS is the app\u2019s, because it always is', (
      tester,
    ) async {
      await pump(tester, profile(ProfileType.link));
      await tester.scrollUntilVisible(find.text('Routing'), 200);
      expect(find.textContaining('DNS by the app'), findsOneWidget);
    });

    testWidgets('the resolver itself is one tap away', (tester) async {
      await pump(
        tester,
        profile(
          ProfileType.subscription,
          dns: ['https://dns.quad9.net/dns-query#PROXY'],
        ),
      );
      await openRouting(tester);
      await tester.tap(find.widgetWithText(ListTile, 'DNS'));
      await tester.pumpAndSettle();
      expect(find.text('https://dns.quad9.net/dns-query'), findsOneWidget);
      expect(find.text('through the tunnel'), findsOneWidget);
    });
  });

  group('the refresh period', () {
    testWidgets('the cadence in force is on the row it belongs to', (
      tester,
    ) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithInterval(12),
      );
      await tester.scrollUntilVisible(find.text('Last refreshed'), 200);
      expect(find.textContaining('auto every 12 h'), findsOneWidget);
    });

    testWidgets('the user’s own period replaces what the panel asked for', (
      tester,
    ) async {
      await pump(
        tester,
        profile(
          ProfileType.subscription,
        ).copyWithInterval(12).copyWith(refreshHours: (value: 6)),
      );
      await tester.scrollUntilVisible(find.text('Last refreshed'), 200);
      expect(find.textContaining('auto every 6 h'), findsOneWidget);
    });

    testWidgets('the gear sits beside the refresh button, not on its own row', (
      tester,
    ) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithInterval(12),
      );
      await tester.scrollUntilVisible(find.text('Last refreshed'), 200);
      expect(find.byTooltip('Refresh every'), findsOneWidget);
      expect(find.byTooltip('Refresh now'), findsOneWidget);
    });
  });

  testWidgets('an Amnezia subscription opens before any server is issued', (
    tester,
  ) async {
    await pump(
      tester,
      Profile(
        id: 'p1',
        type: ProfileType.amnezia,
        name: 'Amnezia Premium',
        locations: [
          Location(
            id: 'amnezia_de_awg',
            label: 'Germany',
            proxy: const {},
            description: 'AmneziaWG',
          ),
        ],
        amnezia: const AmneziaState(
          serviceType: 'amnezia-premium',
          serviceProtocol: 'awg',
          userCountryCode: 'ru',
          account: AmneziaAccount(activeDevices: 5, maxDevices: 7),
        ),
        refreshedAt: DateTime.now(),
      ),
    );

    expect(tester.takeException(), isNull);
    await openRouting(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('DNS'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Amnezia Premium'), findsWidgets);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('5 of 7 used'), findsOneWidget);
    expect(find.text('Runs until'), findsNothing);
  });

  testWidgets('a subscription shows no numbers it was never given', (
    tester,
  ) async {
    await pump(
      tester,
      Profile(
        id: 'p1',
        type: ProfileType.amnezia,
        name: 'Amnezia Premium',
        locations: [
          Location(id: 'amnezia_de_awg', label: 'Germany', proxy: const {}),
        ],
        amnezia: const AmneziaState(
          serviceType: 'amnezia-premium',
          serviceProtocol: 'awg',
          userCountryCode: 'ru',
          account: AmneziaAccount(description: 'Premium, one year.'),
        ),
        refreshedAt: DateTime.now(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Devices'), findsNothing);
    expect(find.text('Runs until'), findsNothing);
    expect(find.textContaining('Premium, one year.'), findsNothing);
  });

  testWidgets('every refresh that fails says so the same way', (tester) async {
    const shared = 'lib/features/refresh_button.dart';
    final pattern = RegExp(r'configRefreshFailed\(');
    expect(
      pattern.allMatches(File(shared).readAsStringSync()),
      hasLength(1),
      reason: '$shared is the one place that says it',
    );
    for (final f in [
      File('lib/features/config/amnezia_config_screen.dart'),
      File('lib/features/config/subscription_config_screen.dart'),
      File('lib/features/config/selfhosted_config_screen.dart'),
      File('lib/features/home_screen.dart'),
    ]) {
      final src = f.readAsStringSync();
      expect(
        src,
        isNot(contains('configRefreshFailed')),
        reason: '${f.path} has grown its own copy of the message',
      );
      expect(
        src,
        anyOf(contains('RefreshCard('), contains('RefreshButton(')),
        reason: '${f.path} offers a refresh, so it must use the shared one',
      );
    }
  });

  testWidgets('a self-hosted configuration is the only one with an account', (
    tester,
  ) async {
    await pump(
      tester,
      profile(
        ProfileType.selfhosted,
        account: Account.fromJson(const {
          'status': 'active',
          'data_limit': 100,
          'used_bytes': 20,
        }),
      ),
    );
    expect(find.text('Account'), findsOneWidget);
    expect(find.textContaining('Traffic:'), findsOneWidget);
    await expectFullWidthButtons(tester);
  });

  testWidgets('a server-set policy replaces the local routing controls', (
    tester,
  ) async {
    await pump(
      tester,
      profile(
        ProfileType.selfhosted,
        routing: const Routing(mode: 'full', rules: []),
      ),
    );
    expect(
      find.textContaining('set by your organization'),
      findsOneWidget,
      reason: 'the row says who owns the policy before it is opened',
    );
    await openRouting(tester);
    expect(find.text('Managed by your organization'), findsOneWidget);
    expect(
      find.text('Rule set'),
      findsNothing,
      reason: 'offering a rule set would promise control this config lacks',
    );
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets(
    'servers the app cannot run are counted in the header and explained',
    (tester) async {
      await pump(
        tester,
        profile(
          ProfileType.subscription,
        ).copyWithUnsupported({'hysteria2': 12}),
      );
      expect(find.text('Subscription · 1 of 13 servers'), findsOneWidget);
      expect(find.text('12 of 13 servers unsupported'), findsOneWidget);
      expect(find.textContaining('hysteria2'), findsOneWidget);
    },
  );

  testWidgets(
    'a configuration with nothing skipped says only how many it has',
    (tester) async {
      await pump(tester, profile(ProfileType.subscription));
      expect(find.text('Subscription · 1 server'), findsOneWidget);
      expect(find.textContaining('unsupported'), findsNothing);
    },
  );

  testWidgets('a refused device is stated on the screen, not only in a toast', (
    tester,
  ) async {
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithDeviceLimitReached(),
    );
    expect(find.text('Device limit reached'), findsOneWidget);
    expect(find.textContaining('Free a slot'), findsOneWidget);
  });

  testWidgets(
    'a subscription\'s routes are applied, attributed and switchable',
    (tester) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithProviderRoutes(),
      );
      await openRouting(tester);
      expect(find.text('SUBSCRIPTION ROUTING'), findsOneWidget);
      expect(
        find.text('Split · 2 rules · 1 not supported'),
        findsOneWidget,
        reason:
            'a summary that reads as complete is the one place this misleads',
      );
      expect(
        find.text('Rule set'),
        findsNWidgets(2),
        reason: 'one row per owner, named the same on both halves',
      );
      final sw = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Split · 2 rules · 1 not supported'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(sw.value, isTrue, reason: 'a provider that sent rules meant them');
      expect(
        find.text('Replaced by the subscription\u2019s routes'),
        findsOneWidget,
        reason:
            'the local set must say why it is dimmed, not just look disabled',
      );
    },
  );

  testWidgets(
    'the device\'s routing is out of reach while the provider\'s is on',
    (tester) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithProviderRoutes(),
      );
      await openRouting(tester);
      expect(_ignoringLocalCard(tester), isTrue);
    },
  );

  testWidgets(
    'and it takes input again the moment the subscription\'s switch is off',
    (tester) async {
      await pump(
        tester,
        profile(
          ProfileType.subscription,
        ).copyWithProviderRoutes(enabled: false),
      );
      await openRouting(tester);
      expect(_ignoringLocalCard(tester), isFalse);
      expect(
        find.text('Replaced by the subscription\u2019s routes'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a rule that needs the subscription\'s lists says so and offers the switch',
    (tester) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithProviderLists(),
        lists: const [],
      );
      await openRouting(tester);
      expect(find.text('Split · 1 rule · 1 needs their lists'), findsOneWidget);
      expect(find.text('Rule lists'), findsOneWidget);
      expect(find.text('Off · 1 rule needs them'), findsOneWidget);
      final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Rule lists'),
      );
      expect(
        sw.value,
        isFalse,
        reason: 'holding someone else\'s files is a separate decision',
      );
    },
  );

  testWidgets('turning their lists on says so, and refuses a second tap', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithProviderLists(),
      lists: const [],
      onSetLists: (_) => gate.future,
    );
    await openRouting(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Rule lists'));
    await tester.pump();

    expect(find.text('Downloading one list…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Rule lists'),
    );
    expect(
      sw.onChanged,
      isNull,
      reason:
          'a second request would not hurry the first, and two writers on '
          'the same files is how half a list lands on disk',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a policy with no external lists is offered no switch for them', (
    tester,
  ) async {
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithProviderRoutes(),
    );
    expect(
      find.text('Rule lists'),
      findsNothing,
      reason: 'a switch that governs nothing is worse than no switch',
    );
  });

  testWidgets(
    'a list that never arrived is reported, with the rest still applied',
    (tester) async {
      await pump(
        tester,
        profile(ProfileType.subscription).copyWithProviderLists(accepted: true),
        lists: const [
          RuleListStatus(
            list: RuleList(
              name: 'reject',
              url: 'https://lists.example/r.yaml',
              behavior: 'domain',
            ),
            error: 'lists.example: timeout',
          ),
        ],
      );
      await openRouting(tester);
      expect(find.text('One list could not be downloaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text('Split · 1 rule · 1 list unavailable'),
        findsOneWidget,
        reason: 'the other rule is still applied, and the gap is still named',
      );
    },
  );

  testWidgets('a downloaded list is counted, not just claimed', (tester) async {
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithProviderLists(accepted: true),
      lists: const [
        RuleListStatus(
          list: RuleList(
            name: 'reject',
            url: 'https://lists.example/r.yaml',
            behavior: 'domain',
          ),
          bytes: 214 * 1024,
        ),
      ],
    );
    await openRouting(tester);
    expect(find.text('Split · 2 rules'), findsOneWidget);
    expect(find.text('1 list · 214 KB'), findsOneWidget);
    expect(find.text('One list could not be downloaded'), findsNothing);
  });

  testWidgets(
    'a subscription with no routes of its own keeps the device controls',
    (tester) async {
      await pump(tester, profile(ProfileType.subscription));
      await openRouting(tester);
      expect(
        find.text('SUBSCRIPTION ROUTING'),
        findsNothing,
        reason: 'nothing came from the panel, so it gets no section',
      );
      expect(find.text('DEVICE ROUTING'), findsOneWidget);
      expect(find.text('Rule set'), findsOneWidget);
    },
  );

  testWidgets('the active configuration offers no "set active" button', (
    tester,
  ) async {
    await pump(tester, profile(ProfileType.link));
    expect(find.text('Set active'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}

extension on Profile {
  Profile copyWithUnsupported(Map<String, int> kinds) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    subscriptionUrl: subscriptionUrl,
    unsupportedServers: kinds,
    refreshedAt: refreshedAt,
  );

  Profile copyWithDeviceLimit() => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    subscriptionUrl: subscriptionUrl,
    deviceLimitActive: true,
    refreshedAt: refreshedAt,
  );

  Profile copyWithProviderRoutes({bool enabled = true}) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    subscriptionUrl: subscriptionUrl,
    providerRouting: const Routing(
      mode: 'split',
      rules: [
        RoutingRule(
          type: 'domain-suffix',
          value: 'ads.example',
          action: 'block',
        ),
        RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
      ],
    ),
    providerRoutingSkipped: 1,
    providerRoutingEnabled: enabled,
    refreshedAt: refreshedAt,
  );

  Profile copyWithInterval(int hours) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    subscriptionUrl: subscriptionUrl,
    providerInfo: SubscriptionInfo.fromHeaders({
      'profile-update-interval': '$hours',
    }),
    refreshedAt: refreshedAt,
  );

  Profile copyWithProviderLists({bool accepted = false}) => Profile(
    id: id,
    type: type,
    name: name,
    locations: locations,
    subscriptionUrl: subscriptionUrl,
    providerRouting: const Routing(
      mode: 'split',
      rules: [
        RoutingRule(type: 'rule-list', value: 'reject', action: 'block'),
        RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
      ],
      lists: [
        RuleList(
          name: 'reject',
          url: 'https://lists.example/r.yaml',
          behavior: 'domain',
        ),
      ],
    ),
    providerRuleListsEnabled: accepted,
    refreshedAt: refreshedAt,
  );

  Profile copyWithDeviceLimitReached() => Profile(
    id: id,
    type: type,
    name: name,
    locations: [
      Location(
        id: 'stub',
        label: 'Device limit reached',
        proxy: {'type': 'vless', 'server': '0.0.0.0', 'port': 1},
      ),
    ],
    subscriptionUrl: subscriptionUrl,
    deviceLimitActive: true,
    deviceLimitReached: true,
    refreshedAt: refreshedAt,
  );
}

bool _ignoringLocalCard(WidgetTester tester) {
  final card = find.ancestor(
    of: find.widgetWithText(SwitchListTile, 'Routing'),
    matching: find.byType(IgnorePointer),
  );
  return tester.widgetList<IgnorePointer>(card).any((w) => w.ignoring);
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles, {this.onSetLists});
  final List<Profile> profiles;

  final Future<void> Function(bool)? onSetLists;

  @override
  ProfilesState build() =>
      ProfilesState(profiles: profiles, activeId: profiles.first.id);

  @override
  Future<void> setProviderRuleListsEnabled(
    String profileId,
    bool enabled,
  ) async {
    if (onSetLists == null) return;
    await onSetLists!(enabled);
  }
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}
