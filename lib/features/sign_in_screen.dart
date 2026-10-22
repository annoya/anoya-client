import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/app_error.dart';
import '../core/ds.dart';
import '../core/log.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.initialServer});

  final String? initialServer;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _server = TextEditingController(text: widget.initialServer ?? '');
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  String? _host() {
    final h = Uri.tryParse(_server.text.trim())?.host;
    return h == null || h.isEmpty ? null : h;
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      final signedIn = await action();
      if (signedIn && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      Log.e('sign in failed', '$e');
      if (mounted) showErrorDialog(context, describeError(e, subject: _host()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
    await _ctrl.addSelfhosted(_server.text, _username.text, _password.text);
    return true;
  });

  Future<void> _ssoSignIn() => _run(() async {
    if (_server.text.trim().isEmpty) {
      throw AppErrorException(AppError(L10n.current.signInEnterServerFirst));
    }
    final cfg = await _ctrl.authConfig(_server.text);
    if (cfg.providers.isEmpty) {
      throw AppErrorException(
        AppError(
          L10n.current.signInNoSsoProviders,
          detail: L10n.current.signInNoSsoProvidersDetail,
        ),
      );
    }
    final provider = cfg.providers.length == 1
        ? cfg.providers.first
        : await _pickProvider(cfg.providers);
    if (provider == null) return false;
    await _ctrl.addSelfhostedOIDC(_server.text, provider);
    return true;
  });

  Future<AuthProvider?> _pickProvider(List<AuthProvider> providers) =>
      pickOption(
        context,
        title: context.l10n.signInWith,
        options: [
          for (final p in providers)
            Option(p, p.name, leading: const GlyphIcon(Glyph.briefcase)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsPage(
      title: l10n.signIn,
      subtitle: l10n.signInSubtitle,
      children: [
        Opacity(
          opacity: _busy ? kDisabledOpacity : 1,
          child: DsStack(
            children: [
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.signInServerAddress,
                  hintText: l10n.signInServerHint,
                ),
              ),
              TextField(
                controller: _username,
                autocorrect: false,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l10n.signInUsername),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l10n.signInPassword),
                onSubmitted: (_) => _busy ? null : _signIn(),
              ),
            ],
          ),
        ),
        DsStack(
          children: [
            DsButton(label: l10n.signIn, busy: _busy, onPressed: _signIn),
            DsButton.secondary(
              label: l10n.signInWithSso,
              glyph: Glyph.briefcase,
              onPressed: _busy ? null : _ssoSignIn,
            ),
          ],
        ),
      ],
    );
  }
}
