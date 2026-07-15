import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/log.dart';
import '../state/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      Log.i('login attempt: server="${_server.text}" user="${_username.text}"');
      await ref.read(authControllerProvider.notifier).login(_server.text, _username.text, _password.text);
      Log.i('login succeeded');
    } on ApiException catch (e) {
      Log.e('login failed (${e.code})', e.message);
      setState(() => _error = e.message);
    } catch (e, st) {
      Log.e('login failed (unexpected)', e, st);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fetch the server's SSO providers, let the user pick one (if several), and
  /// run the browser OIDC flow. The server address must be filled first.
  Future<void> _ssoLogin() async {
    if (_server.text.trim().isEmpty) {
      setState(() => _error = 'Enter the server address first.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      final cfg = await auth.authConfig(_server.text);
      if (cfg.providers.isEmpty) {
        setState(() => _error = 'This server has no SSO providers configured.');
        return;
      }
      final provider = cfg.providers.length == 1 ? cfg.providers.first : await _pickProvider(cfg.providers);
      if (provider == null) return; // user dismissed the picker
      await auth.loginOIDC(_server.text, provider);
      Log.i('SSO login succeeded via ${provider.name}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      Log.e('SSO login failed', '$e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<AuthProvider?> _pickProvider(List<AuthProvider> providers) {
    return showModalBottomSheet<AuthProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Sign in with', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...providers.map((p) => ListTile(
                  leading: const Icon(Icons.login),
                  title: Text(p.name),
                  onTap: () => Navigator.of(context).pop(p),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Icon(Icons.vpn_lock, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Sign in', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'http://your-server:8080',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _username,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or')),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _ssoLogin,
                      icon: const Icon(Icons.business_outlined, size: 18),
                      label: const Text('Sign in with SSO'),
                    ),
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
