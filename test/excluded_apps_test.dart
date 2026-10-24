import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/excluded_apps_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/excluded_apps_controller.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const control = MethodChannel('vpn/control');

  late List<String> saved;
  List<String>? inUse;
  late List<MethodCall> calls;

  setUp(() {
    saved = ['ru.sberbankmobile'];
    inUse = null;
    calls = [];
    messenger.setMockMethodCallHandler(control, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'excluded_apps':
          return saved;
        case 'set_excluded_apps':
          saved = List<String>.from(call.arguments['packages'] as List);
          return null;
        case 'excluded_apps_in_use':
          return inUse;
        case 'installed_apps':
          return [
            {'package': 'ru.sberbankmobile', 'label': 'SberBank Online'},
            {'package': 'ru.rostel', 'label': 'Gosuslugi'},
          ];
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(control, null));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [vpnCoreProvider.overrideWithValue(_Core())],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'a change waits for a reconnect only while a tunnel runs the old list',
    () {
      expect(
        const ExcludedApps(packages: ['a']).pending,
        isFalse,
        reason: 'no tunnel: the next connect takes the list anyway',
      );
      expect(
        const ExcludedApps(packages: ['a', 'b'], inUse: ['b', 'a']).pending,
        isFalse,
        reason: 'the same apps in another order',
      );
      expect(
        const ExcludedApps(packages: ['a', 'b'], inUse: ['a']).pending,
        isTrue,
      );
    },
  );

  test(
    'the list is read from and written to the tunnel service, sorted and once each',
    () async {
      final c = container();
      c.read(excludedAppsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(excludedAppsProvider).packages, ['ru.sberbankmobile']);

      await c.read(excludedAppsProvider.notifier).setApps([
        'ru.rostel',
        'ru.sberbankmobile',
        'ru.rostel',
      ]);

      expect(saved, ['ru.rostel', 'ru.sberbankmobile']);
      expect(c.read(excludedAppsProvider).packages, saved);
    },
  );

  testWidgets(
    'reconnecting is offered only when the running tunnel uses another list',
    (tester) async {
      inUse = ['ru.sberbankmobile', 'ru.rostel'];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [vpnCoreProvider.overrideWithValue(_Core())],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExcludedAppsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SberBank Online'), findsOneWidget);
      expect(find.text('Reconnect now'), findsOneWidget);

      await tester.tap(find.text('Reconnect now'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), contains('restart_tunnel'));

      inUse = ['ru.sberbankmobile'];
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(
        find.text('Reconnect now'),
        findsOneWidget,
        reason: 'the tunnel still keeps SberBank out until it restarts',
      );
    },
  );
}

class _Core extends VpnCore {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}
}
