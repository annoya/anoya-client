import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/connection_check.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/features/advanced_connection_screen.dart';
import 'package:vpn_client/state/connection_check_controller.dart';
import 'package:vpn_client/state/providers.dart';

/// What "connected" leaves out.
///
/// The system reports an interface, not a path: an AmneziaWG peer whose
/// handshake never completes and a VLESS server that accepts TCP and then says
/// nothing both leave a tunnel that looks perfectly up and carries nothing.
/// Everything here is about telling those two apart from a working one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    // The prefs live in a file; the tests are about behaviour, not storage —
    // and a temp dir keeps a test run from leaving one in the repository.
    tmp = Directory.systemTemp.createTempSync('vpn-connection-check');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    tmp.deleteSync(recursive: true);
  });

  /// The controller reads its prefs from a file before it will probe, so the
  /// trigger tests have to wait for real async work rather than a microtask.
  Future<void> until(bool Function() done,
      {Duration timeout = const Duration(milliseconds: 500)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  ProviderContainer boot(_FakeCore core) {
    final c = ProviderContainer(overrides: [vpnCoreProvider.overrideWithValue(core)]);
    addTearDown(c.dispose);
    c.read(connectionCheckProvider);
    return c;
  }

  group('what the engine answers', () {
    test('a delay is a pass, and it is kept', () {
      final r = ConnectionCheck.parse('ms:143', at: DateTime.now(), via: 'Netherlands #2');
      expect(r.passed, isTrue);
      expect(r.delayMs, 143);
      expect(r.via, 'Netherlands #2');
    });

    test('a refusal is turned into a sentence, not left as a code', () {
      final r = ConnectionCheck.parse('err:the tunnel is not running', at: DateTime.now());
      expect(r.passed, isFalse);
      expect(r.failure, 'The tunnel is not running.');
    });

    test('an answer we cannot read is a failure, never a zero-millisecond pass', () {
      // 0 ms and "no answer" are indistinguishable once a number is all the
      // caller gets, which is why the engine answers in prefixed strings.
      expect(ConnectionCheck.parse('', at: DateTime.now()).passed, isFalse);
      expect(ConnectionCheck.parse('ms:', at: DateTime.now()).passed, isFalse);
      expect(ConnectionCheck.parse('nonsense', at: DateTime.now()).failure, 'nonsense.');
    });
  });

  group('when it runs', () {
    test('a session coming up is the trigger, not the Connect button', () async {
      // A tunnel raised by an on-demand rule or Android's always-on switch is
      // the one nobody is watching, and "up but carrying nothing" matters
      // there most.
      final core = _FakeCore(answer: 'ms:120');
      final c = boot(core);
      await Future<void>.delayed(Duration.zero);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));

      expect(core.probes, 1);
      expect(c.read(connectionCheckProvider).last?.delayMs, 120);
    });

    test('a measurement does not outlive the session it describes', () async {
      final core = _FakeCore(answer: 'ms:120');
      final c = boot(core);
      await Future<void>.delayed(Duration.zero);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));
      expect(c.read(connectionCheckProvider).last, isNotNull);

      core.emit(VpnStatus.disconnected);
      await until(() => c.read(connectionCheckProvider).last == null,
          timeout: const Duration(seconds: 2));
      expect(c.read(connectionCheckProvider).last, isNull,
          reason: 'a green line under a dead tunnel is worse than no line');
    });

    test('switched off, nothing is sent to anybody', () async {
      // The probe leaves the device for somebody else's host on every connect;
      // refusing to send it has to actually mean that.
      final core = _FakeCore(answer: 'ms:120');
      final c = boot(core);
      await c.read(connectionCheckProvider.notifier).setEnabled(false);

      core.emit(VpnStatus.connected);
      // Past the warm-up and the first retry: if it were going to probe, it
      // would have by now.
      await until(() => core.probes > 0, timeout: const Duration(seconds: 5));

      expect(core.probes, 0);
      expect(c.read(connectionCheckProvider).last, isNull);
    });

    test('the button still probes with the check switched off', () async {
      final core = _FakeCore(answer: 'ms:88');
      final c = boot(core);
      await c.read(connectionCheckProvider.notifier).setEnabled(false);

      final result = await c.read(connectionCheckProvider.notifier).run();

      expect(result.delayMs, 88);
      expect(core.probes, 1);
    });

    test('a failure is a result, not an exception', () async {
      final core = _FakeCore(answer: 'err:context deadline exceeded');
      final c = boot(core);

      final result = await c.read(connectionCheckProvider.notifier).run();

      expect(result.passed, isFalse);
      expect(c.read(connectionCheckProvider).last?.failure,
          'The server did not answer in time.');
    });

    test('the settings the user chose are the ones sent', () async {
      final core = _FakeCore(answer: 'ms:10');
      final c = boot(core);
      final ctrl = c.read(connectionCheckProvider.notifier);
      await ctrl.setUrl('https://example.com/ping');
      await ctrl.setTimeout(15);

      await ctrl.run();

      expect(core.lastUrl, 'https://example.com/ping');
      expect(core.lastTimeout, const Duration(seconds: 15));
    });
  });

  group('the check nobody had to send', () {
    test('traffic that already came back is the answer', () async {
      // The user was browsing; the tunnel proved itself with their own bytes.
      // Sending a HEAD to somebody else's host to learn what we already know
      // is a request that should never leave the device.
      final core = _FakeCore(answers: ['ms:120'], bytes: '4096:65536');
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));

      expect(core.probes, 0, reason: 'nothing needed asking');
      final last = c.read(connectionCheckProvider).last!;
      expect(last.passed, isTrue);
      expect(last.observed, isTrue);
      expect(last.delayMs, isNull, reason: 'we measured nothing, so we claim nothing');
    });

    test('bytes only counted when something came back', () async {
      // Upload alone is a request that may have gone nowhere: packets left,
      // and that is exactly what a dead tunnel looks like from this side.
      final core = _FakeCore(answers: ['ms:120'], bytes: '4096:0');
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));

      expect(core.probes, 1);
      expect(c.read(connectionCheckProvider).last!.observed, isFalse);
    });

    test('the button always asks, whatever the counters say', () async {
      // "Test now" is a question about now. Answering it with an observation
      // made a minute ago would be a button that does nothing.
      final core = _FakeCore(answers: ['ms:77'], bytes: '4096:65536');
      final c = boot(core);

      final result = await c.read(connectionCheckProvider.notifier).run();

      expect(core.probes, 1);
      expect(result.delayMs, 77);
    });
  });

  group('a tunnel that is still coming up', () {
    // The bug this group exists for: on an Amnezia subscription the automatic
    // check reported "No answer" on both AWG and VLESS, and pressing Test now
    // straight afterwards passed. An AmneziaWG peer only begins its handshake
    // when the first packet asks for one, and amneziawg-go retries a lost
    // initiation after RekeyTimeout — five seconds, exactly the probe's own
    // default timeout. The probe was losing a race, not finding a dead server.
    test('the first no is not the answer', () async {
      final core = _FakeCore(answers: ['err:context deadline exceeded', 'ms:180']);
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));

      expect(core.probes, 2);
      expect(c.read(connectionCheckProvider).last!.passed, isTrue,
          reason: 'the server was working; only the handshake was not ready');
    });

    test('a failure that never recovers is still reported', () async {
      final core = _FakeCore(answers: ['err:EOF']);
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 20));

      expect(core.probes, kCheckAttempts);
      expect(c.read(connectionCheckProvider).last!.passed, isFalse);
    });

    test('nothing is published until the sequence has a verdict', () async {
      // An intermediate failure would raise the banner on the home screen and
      // then take it back — a warning that flashes teaches people to ignore it.
      final core = _FakeCore(answers: ['err:context deadline exceeded', 'ms:180']);
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => core.probes == 1, timeout: const Duration(seconds: 12));
      expect(c.read(connectionCheckProvider).last, isNull);

      await until(() => c.read(connectionCheckProvider).last != null,
          timeout: const Duration(seconds: 12));
      expect(c.read(connectionCheckProvider).last!.passed, isTrue);
    });

    test('a session that ends mid-sequence gets no verdict at all', () async {
      final core = _FakeCore(answers: ['err:context deadline exceeded']);
      final c = boot(core);

      core.emit(VpnStatus.connected);
      await until(() => core.probes == 1, timeout: const Duration(seconds: 12));
      core.emit(VpnStatus.disconnected);
      await Future<void>.delayed(const Duration(seconds: 5));

      expect(c.read(connectionCheckProvider).last, isNull,
          reason: 'a verdict about a tunnel that no longer exists is noise');
    });
  });

  group('what a failure reads like', () {
    test('the dial chain becomes a sentence about the server', () {
      // What the engine actually handed us on AWG, both attempts of one
      // request: the addresses are somebody else's CDN and "dial" is a word
      // from the dialer.
      const awg = 'connect failed: dial tcp 172.253.144.94:443: context deadline exceeded\n'
          'connect failed: dial tcp [2404:6800:4003:c02::5e]:443: network is unreachable';
      expect(describeProbeFailure(awg), 'The server did not answer in time.');
      // And on VLESS, where the server accepted the connection and dropped it.
      expect(describeProbeFailure('Head "https://www.gstatic.com/generate_204": EOF'),
          'The server closed the connection.');
    });

    test('a failure we have never seen is quoted, not guessed at', () {
      expect(describeProbeFailure('connect failed: something new'), 'something new.');
    });
  });

  group('the screen', () {
    /// The controller reads its prefs from disk. Created inside the fake async
    /// zone a widget test runs in, that read never completes — so the provider
    /// is built (and its file work finished) in the real zone first.
    Future<ProviderContainer> pump(WidgetTester tester, _FakeCore core) async {
      final container =
          ProviderContainer(overrides: [vpnCoreProvider.overrideWithValue(core)]);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        container.read(connectionCheckProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const AdvancedConnectionScreen(),
        ),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('a probe cannot be asked for with nothing running', (tester) async {
      // The probe goes through the engine, and a button that answers "the
      // tunnel is not running" reads as a fault rather than as the obvious.
      final core = _FakeCore(answer: 'ms:120');
      await pump(tester, core);
      await tester.pump();

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Test now'));
      expect(button.onPressed, isNull);
      expect(find.textContaining('the tunnel has to be up'), findsOneWidget);
    });

    testWidgets('the answer stays on the screen as a line to compare with',
        (tester) async {
      final core = _FakeCore(answer: 'ms:143');
      core.emit(VpnStatus.connected);
      await pump(tester, core);
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Test now'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Answered in 143 ms'), findsOneWidget);
      expect(find.text('LAST CHECK'), findsOneWidget);
    });

    testWidgets('a failure says where the fault is not', (tester) async {
      // Without the second sentence people start reinstalling the app.
      final core = _FakeCore(answer: 'err:context deadline exceeded');
      core.emit(VpnStatus.connected);
      await pump(tester, core);
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Test now'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('No answer'), findsOneWidget);
      expect(find.textContaining('the server or the network beyond it'), findsOneWidget);
    });
  });
}

class _FakeCore extends VpnCore {
  _FakeCore({String? answer, List<String>? answers, this.bytes = '0:0'})
      : answers = answers ?? [answer ?? 'ms:1'];

  /// What the engine's connection tracking reports, as `up:down`.
  final String bytes;

  /// One answer per probe; the last one repeats, so a single-element list is a
  /// server that behaves the same way every time.
  final List<String> answers;
  final _status = StreamController<VpnStatus>.broadcast();
  VpnStatus _current = VpnStatus.disconnected;

  int probes = 0;
  String lastUrl = '';
  Duration lastTimeout = Duration.zero;

  void emit(VpnStatus s) {
    _current = s;
    _status.add(s);
  }

  @override
  Future<String> urlTest(String url, Duration timeout) async {
    lastUrl = url;
    lastTimeout = timeout;
    final answer = answers[probes < answers.length ? probes : answers.length - 1];
    probes++;
    return answer;
  }

  @override
  Future<String> proxyBytes() async => bytes;

  @override
  VpnStatus get status => _current;

  @override
  Stream<VpnStatus> statusStream() => _status.stream;

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> applyOnDemand(OnDemandPrefs prefs,
          {NormConfig? config, String? locationId}) async =>
      false;
}
