import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/api/api_client.dart';
import 'package:anoya/core/oidc_login.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/sign_in_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/profiles_controller.dart';

void main() {
  Future<void> pump(WidgetTester tester, Object failure) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesControllerProvider.overrideWith(() => _SsoFails(failure)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SignInScreen(initialServer: 'https://vpn.example.com'),
        ),
      ),
    );
    await tester.tap(find.text('Sign in with SSO'));
    await tester.pumpAndSettle();
  }

  testWidgets('closing the browser window is not reported as an error', (
    tester,
  ) async {
    await pump(tester, OidcCancelled());

    expect(find.text('Sign-in didn’t finish'), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a provider that refuses is still reported', (tester) async {
    await pump(tester, OidcException('Token exchange failed (400).'));

    expect(find.text('Sign-in didn’t finish'), findsOneWidget);
  });
}

class _SsoFails extends ProfilesController {
  _SsoFails(this.failure);
  final Object failure;

  @override
  ProfilesState build() => const ProfilesState();

  @override
  Future<AuthConfig> authConfig(String serverUrl) async => AuthConfig(
    passwordLogin: true,
    providers: [
      AuthProvider(
        id: 1,
        name: 'Okta',
        issuer: 'https://id.example.com',
        clientId: 'vpn',
      ),
    ],
  );

  @override
  Future<void> addSelfhostedOIDC(String serverUrl, AuthProvider provider) =>
      Future.error(failure);
}
