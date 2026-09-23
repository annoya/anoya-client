import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/app_error.dart';
import '../core/log.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';

/// Self-hosted sign-in: server address + credentials, or SSO when the server
/// offers providers. Reached from the start screen ("Sign in to your server")
/// or via server-address detection.
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

  /// The action returns true only when the sign-in actually happened; false
  /// means the user backed out (dismissed the provider sheet) — the screen
  /// stays, with the typed server address intact.
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
    // Already worded for the user: a FormatException here would be read by
    // describeError as "this doesn't look like a link".
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
    if (provider == null) return false; // sheet dismissed — user backed out
    await _ctrl.addSelfhostedOIDC(_server.text, provider);
    return true;
  });

  Future<AuthProvider?> _pickProvider(List<AuthProvider> providers) =>
      pickOption(
        context,
        title: context.l10n.signInWith,
        options: [
          for (final p in providers)
            Option(p, p.name, leading: const Icon(Icons.login)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signIn)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.business_outlined, size: 48, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(
                    l10n.signInSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    autocorrect: false,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.signInUsername),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.signInPassword),
                    onSubmitted: (_) => _busy ? null : _signIn(),
                  ),
                  const SizedBox(height: 20),
                  // Heights come from the theme (48 for both), so the stack
                  // stays even — no per-button SizedBox.
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.signIn),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _ssoSignIn,
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(l10n.signInWithSso),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
