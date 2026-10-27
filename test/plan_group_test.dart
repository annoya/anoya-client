import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/device_identity.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/subscription_info.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/config/config_parts.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  Profile subscription(
    SubscriptionInfo? info, {
    bool active = false,
    bool reached = false,
  }) => Profile(
    id: 'sub',
    type: ProfileType.subscription,
    name: 'Kopatych VPN',
    subscriptionUrl: 'https://sub.example/t',
    providerInfo: info,
    deviceLimitActive: active,
    deviceLimitReached: reached,
    locations: [
      Location(id: 's1', label: 'Germany', proxy: const {'type': 'vless'}),
    ],
  );

  Future<void> plan(
    WidgetTester tester,
    SubscriptionInfo? info, {
    bool active = false,
    bool reached = false,
  }) => pump(
    tester,
    SubscriptionPlanGroup(
      profile: subscription(info, active: active, reached: reached),
    ),
  );

  DateTime inDays(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + days, 12);
  }

  testWidgets('the term says how much is left, not only the date', (
    tester,
  ) async {
    await plan(
      tester,
      SubscriptionInfo(totalBytes: 100, usedBytes: 38, expiresAt: inDays(46)),
    );
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('46 days left'), findsOneWidget);
    expect(find.textContaining('Active until'), findsOneWidget);
    expect(find.text('Traffic'), findsOneWidget);
  });

  testWidgets('the last day reads as today', (tester) async {
    final now = DateTime.now();
    await plan(
      tester,
      SubscriptionInfo(
        expiresAt: DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
    );
    expect(find.text('Ends today'), findsOneWidget);
  });

  testWidgets('an expired subscription says so in words', (tester) async {
    await plan(tester, SubscriptionInfo(expiresAt: inDays(-92)));
    expect(find.text('Subscription has expired'), findsOneWidget);
    expect(find.textContaining('Ended on'), findsOneWidget);
  });

  testWidgets('a plan without an end date says that it has none', (
    tester,
  ) async {
    await plan(tester, const SubscriptionInfo(usedBytes: 1));
    expect(find.text('No expiry date given'), findsOneWidget);
  });

  testWidgets('a date alone does not invent a traffic figure', (tester) async {
    await plan(tester, SubscriptionInfo(expiresAt: inDays(3)));
    expect(find.text('Traffic'), findsNothing);
  });

  testWidgets('a renew link sits above support', (tester) async {
    await plan(
      tester,
      SubscriptionInfo(
        expiresAt: inDays(2),
        supportUrl: 'https://t.me/example_bot',
        renewUrl: 'https://pay.example/renew',
      ),
    );
    final renew = tester.getTopLeft(find.text('Renew subscription')).dy;
    final support = tester.getTopLeft(find.text('Get support')).dy;
    expect(renew, lessThan(support));
  });

  testWidgets('without a renew link there is only support', (tester) async {
    await plan(
      tester,
      SubscriptionInfo(
        expiresAt: inDays(-1),
        supportUrl: 'https://t.me/example_bot',
      ),
    );
    expect(find.text('Renew subscription'), findsNothing);
    expect(find.text('Get support'), findsOneWidget);
  });

  testWidgets('a panel shows devices only once the limit is reached', (
    tester,
  ) async {
    await plan(tester, const SubscriptionInfo(usedBytes: 1), active: true);
    expect(
      find.text('Devices'),
      findsNothing,
      reason: 'the panel sends no counter, so the row would say nothing',
    );

    await plan(tester, null, active: true, reached: true);
    expect(find.text('No free slots'), findsOneWidget);
  });

  testWidgets('a self-hosted account reads like a subscription', (
    tester,
  ) async {
    await pump(
      tester,
      PlanGroup(
        caption: 'Account',
        rows: [
          TermRow(endsAt: inDays(46)),
          const TrafficRow(used: 38, total: 100),
        ],
      ),
    );
    expect(find.text('46 days left'), findsOneWidget);
    expect(find.text('Traffic'), findsOneWidget);
  });

  group('this device', () {
    setUp(
      () => DeviceIdentityStore.debugCache(
        const DeviceIdentity(
          hwid: '7f3a9c21e4b8a0d2c6f15d0146',
          os: 'iOS',
          osVersion: '18.0',
          model: 'iPhone16,1',
        ),
      ),
    );
    tearDown(() => DeviceIdentityStore.debugCache(null));

    testWidgets('a panel subscription shows its HWID even without a limit', (
      tester,
    ) async {
      await pump(tester, const ThisDeviceSection(counted: false));
      await tester.pump();
      expect(find.text('HWID'), findsOneWidget);
      expect(
        find.text('Sent to the subscription with every refresh'),
        findsOneWidget,
        reason: 'it is not counted, so the row must not say it is',
      );
    });

    testWidgets('a counting panel is told it counts', (tester) async {
      await pump(tester, const ThisDeviceSection(counted: true));
      await tester.pump();
      expect(
        find.text('Identified to your subscription, which counts devices'),
        findsOneWidget,
      );
    });
  });
}
