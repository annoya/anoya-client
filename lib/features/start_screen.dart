import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/log.dart';
import '../state/profiles_controller.dart';

/// First-run / add-configuration screen. Two ways in:
///  - self-hosted sign-in (password or SSO) → a selfhosted profile;
///  - paste a subscription URL / share link, or open a file → subscription/link.
/// On success the app shell (app.dart) swaps to Home automatically.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

enum _Mode { selfhosted, link }

class _StartScreenState extends ConsumerState<StartScreen> {
  _Mode _mode = _Mode.selfhosted;

  // self-hosted
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  // link / subscription
  final _input = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _input.dispose();
    super.dispose();
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await action();
      // First run: app.dart watches hasProfiles and swaps to Home. When pushed
      // from Settings ("Add configuration"), pop back to Home instead.
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      Log.e('add configuration failed', '$e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() =>
      _run(() => _ctrl.addSelfhosted(_server.text, _username.text, _password.text));

  Future<void> _ssoSignIn() => _run(() async {
        if (_server.text.trim().isEmpty) throw const FormatException('Enter the server address first.');
        final cfg = await _ctrl.authConfig(_server.text);
        if (cfg.providers.isEmpty) throw const FormatException('This server has no SSO providers.');
        final provider = cfg.providers.length == 1 ? cfg.providers.first : await _pickProvider(cfg.providers);
        if (provider == null) return;
        await _ctrl.addSelfhostedOIDC(_server.text, provider);
      });

  Future<void> _addInput() => _run(() async {
        final t = _input.text.trim();
        if (t.isEmpty) throw const FormatException('Paste a link or subscription URL.');
        final scheme = t.split('://').first.toLowerCase();
        if (const {'vless', 'vmess', 'trojan', 'ss'}.contains(scheme)) {
          await _ctrl.addFromText(t);
        } else if (t.startsWith('http://') || t.startsWith('https://')) {
          await _ctrl.addSubscriptionUrl('', t);
        } else {
          await _ctrl.addFromText(t); // pasted base64 / clash yaml
        }
      });

  Future<void> _openFile() => _run(() async {
        final res = await FilePicker.platform.pickFiles(withData: true);
        if (res == null) return;
        final bytes = res.files.single.bytes;
        if (bytes == null) throw const FormatException('Could not read the file.');
        await _ctrl.addFromText(utf8.decode(bytes), name: res.files.single.name);
      });

  Future<AuthProvider?> _pickProvider(List<AuthProvider> providers) {
    return showModalBottomSheet<AuthProvider>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Sign in with')),
          ...providers.map((p) => ListTile(
                leading: const Icon(Icons.login),
                title: Text(p.name),
                onTap: () => Navigator.of(context).pop(p),
              )),
          const SizedBox(height: 8),
        ]),
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
                  const SizedBox(height: 16),
                  Icon(Icons.shield_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Add a connection',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  SegmentedButton<_Mode>(
                    segments: const [
                      ButtonSegment(value: _Mode.selfhosted, label: Text('Sign in'), icon: Icon(Icons.dns_outlined)),
                      ButtonSegment(value: _Mode.link, label: Text('Link / file'), icon: Icon(Icons.link)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _busy ? null : (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 20),
                  if (_mode == _Mode.selfhosted) ..._selfhosted() else ..._link(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _selfhosted() => [
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Server address', hintText: 'https://your-server'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _username, autocorrect: false, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (_) => _busy ? null : _signIn(),
        ),
        const SizedBox(height: 20),
        _primary('Sign in', _signIn),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _ssoSignIn,
          icon: const Icon(Icons.business_outlined, size: 18),
          label: const Text('Sign in with SSO'),
        ),
      ];

  List<Widget> _link() => [
        TextField(
          controller: _input,
          maxLines: 3,
          minLines: 1,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Subscription URL, or a vless:// / vmess:// / trojan:// / ss:// link',
            hintText: 'https://…/sub  or  vless://…',
          ),
        ),
        const SizedBox(height: 20),
        _primary('Add', _addInput),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _openFile,
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Open a file…'),
        ),
      ];

  Widget _primary(String label, Future<void> Function() onTap) => SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : onTap,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        ),
      );
}
