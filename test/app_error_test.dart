import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/api/api_client.dart';
import 'package:anoya/core/app_error.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/ui.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  group('describeError', () {
    test('never leaks the exception text into the message', () {
      final errors = <Object>[
        const SocketException('Connection refused (OS Error: ...), port = 443'),
        TimeoutException('after 0:00:10.000000'),
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        const FormatException('Unexpected character'),
        ApiException(500, 'internal', 'sql: no rows in result set'),
        PlatformException(code: 'NEVPNErrorConfigurationInvalid'),
        StateError('shared container unavailable'),
      ];
      for (final e in errors) {
        final described = describeError(e, subject: 'vpn.example.com');
        expect(described.line, isNot(contains('OS Error')));
        expect(described.line, isNot(contains('Exception')));
        expect(described.line, isNot(contains('sql:')));
        expect(described.title, isNotEmpty);
        expect(
          described.detail,
          isNotNull,
          reason: 'the second line is what tells the user what to do',
        );
      }
    });

    test('a message already worded for the user arrives untouched', () {
      const worded = AppError(
        'Enter the server address first',
        detail: 'Then try again.',
      );
      final described = describeError(const AppErrorException(worded));
      expect(described.title, worded.title);
      expect(described.detail, worded.detail);
    });

    test('names the subject so the user knows what to fix', () {
      final e = describeError(
        const SocketException('nope'),
        subject: 'de1.example.com',
      );
      expect(e.detail, contains('de1.example.com'));
      expect(
        describeError(const SocketException('nope')).detail,
        contains('the server'),
      );
    });

    test('a missing tunnel service is named, not blamed on a VPN profile', () {
      final absent = describeError(
        PlatformException(code: 'service_unavailable'),
      );
      expect(absent.title, 'The tunnel service isn’t running');
      expect(
        absent.detail,
        contains(Platform.isLinux ? 'anoya-tunnel' : 'AnoyaTunnel'),
      );
      expect(absent.detail, isNot(contains('profile')));
      final gone = describeError(
        PlatformException(code: 'service_disconnected'),
      );
      expect(gone.title, 'The tunnel service stopped');
      expect(gone.detail, contains('connect again'));
    });

    test('a bad password is not the same message as an expired session', () {
      final wrong = describeError(
        ApiException(401, 'invalid_credentials', 'unauthorized'),
      );
      final expired = describeError(
        ApiException(401, 'token_expired', 'unauthorized'),
      );
      expect(wrong.title, 'Wrong username or password');
      expect(expired.title, 'Session expired');
    });

    test('account states are explained, not printed', () {
      expect(describeAccountStatus('expired').title, 'Subscription expired');
      expect(describeAccountStatus('limited').title, 'Traffic limit reached');
      expect(describeAccountStatus('deactivated').title, 'Access disabled');
      expect(
        describeAccountStatus('on_hold').title,
        'Subscription not started',
      );
      expect(
        describeAccountStatus('some_new_state').title,
        'Account is some new state',
      );
    });
  });

  group('presentation', () {
    testWidgets('a toast disappears on its own and closes on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showToast(context, 'Couldn’t refresh the subscription'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Couldn’t refresh the subscription'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Couldn’t refresh the subscription'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t refresh the subscription'), findsNothing);

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an error dialog blocks the screen until the cross is pressed', (
      tester,
    ) async {
      var dismissed = false;
      var connectTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => connectTaps++,
                    child: const Text('Connect'),
                  ),
                  TextButton(
                    onPressed: () => showErrorDialog(
                      context,
                      const AppError(
                        'Couldn’t reach the server',
                        detail:
                            'de1.example.com didn’t answer. Check your network.',
                      ),
                      onDismiss: () => dismissed = true,
                    ),
                    child: const Text('fail'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t reach the server'), findsOneWidget);
      expect(find.textContaining('de1.example.com'), findsOneWidget);

      final scheme = buildAppTheme(Brightness.light).colorScheme;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, isNot(scheme.errorContainer));
      expect(material.color, isNot(scheme.error));

      expect(find.byType(ModalBarrier), findsWidgets);
      await tester.tap(find.text('Connect'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(connectTaps, 0, reason: 'the dialog blocks the UI behind it');

      await tester.pump(const Duration(seconds: 10));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t reach the server'), findsOneWidget);
      expect(dismissed, false);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t reach the server'), findsNothing);
      expect(
        dismissed,
        true,
        reason: 'the caller must be able to clear its error',
      );

      await tester.tap(find.text('Connect'));
      expect(connectTaps, 1);
    });
  });
}
