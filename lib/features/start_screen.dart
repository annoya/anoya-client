import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/log.dart';
import '../core/proxy_uri.dart';
import '../state/profiles_controller.dart';
import 'sign_in_screen.dart';

/// Add-a-connection screen (first run, or pushed from the home "+").
/// Two explicit paths:
///  - paste a link / subscription (live-detected) or open a config file;
///  - "Sign in to your server" → the self-hosted sign-in screen.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final _input = TextEditingController();
  DetectedInput? _detected;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  void _onChanged(String v) => setState(() {
        _detected = detectInput(v);
        _error = null;
      });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await action();
      // First run: app.dart swaps to Home when a profile appears. Pushed from
      // home/settings: unwind whatever is above the root.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      Log.e('add configuration failed', '$e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final t = _input.text.trim();
    final d = _detected;
    if (d == null) return;
    if (d.kind == InputKind.subscriptionUrl) {
      // Fetch as a subscription; when it isn't one, probe whether it's a
      // management server and hand over to sign-in instead of failing.
      setState(() {
        _error = null;
        _busy = true;
      });
      try {
        await _ctrl.addSubscriptionUrl('', t);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } on FormatException catch (fe) {
        try {
          await _ctrl.authConfig(t);
        } catch (_) {
          if (mounted) setState(() => _error = fe.message);
          return;
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SignInScreen(initialServer: t)),
          );
        }
      } catch (e) {
        Log.e('add subscription failed', '$e');
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    await _run(() => _ctrl.addFromText(t));
  }

  Future<void> _openFile() => _run(() async {
        final res = await FilePicker.platform.pickFiles(withData: true);
        if (res == null) return;
        final bytes = res.files.single.bytes;
        if (bytes == null) throw const FormatException('Could not read the file.');
        await _ctrl.addFromText(utf8.decode(bytes), name: res.files.single.name);
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Navigator.of(context).canPop() ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 14),
                  Text('Add a connection',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Link, subscription or config file',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enabled: !_busy,
                    onChanged: _onChanged,
                    decoration: const InputDecoration(
                      labelText: 'Link or subscription',
                      hintText: 'vless://…  or  https://…/sub',
                    ),
                  ),
                  if (_detected != null) ...[
                    const SizedBox(height: 10),
                    _DetectChip(text: _detected!.label),
                  ],
                  const SizedBox(height: 14),
                  // All three buttons take their 48pt height from the theme.
                  FilledButton(
                    onPressed: (_busy || _detected == null) ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open a config file…'),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignInScreen()),
                            ),
                    icon: const Icon(Icons.business_outlined, size: 18),
                    label: const Text('Sign in to your server'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectChip extends StatelessWidget {
  const _DetectChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
        ),
      ]),
    );
  }
}
