import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/app_error.dart';
import '../core/log.dart';
import '../core/parsers/subscription.dart';
import '../core/theme.dart';
import '../core/ui.dart';
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
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  /// What the message should name: the host the user typed, when there is one.
  String? _subject() {
    final text = _input.text.trim();
    if (!text.startsWith('http')) return null;
    return Uri.tryParse(text)?.host.isNotEmpty == true ? Uri.parse(text).host : null;
  }

  /// A body the panel answered with that we could not turn into servers.
  ///
  /// Shown inline rather than in the error dialog, because it is not a failure
  /// the user can fix by retyping: it needs reading, and often a visit to the
  /// provider's page. A modal that has to be dismissed to see the field again
  /// would hide the one action that helps.
  SubscriptionFormatException? _rejected;

  void _onChanged(String v) => setState(() {
        _detected = detectInput(v);
        _rejected = null;
      });

  /// The action returns true when a configuration was actually added; false
  /// means the user backed out (cancelled a picker) — the screen must stay,
  /// closing it would read as a phantom success.
  Future<void> _run(Future<bool> Function() action) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final added = await action();
      // Before the pop, and deliberately: the toast lives in the root
      // ScaffoldMessenger, so it survives the unwind and lands on the screen
      // the user ends up looking at.
      if (added) _warnIfRefused(container, messenger);
      // First run: app.dart swaps to Home when a profile appears. Pushed from
      // home/settings: unwind whatever is above the root.
      if (added && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on SubscriptionFormatException catch (e) {
      Log.e('add configuration rejected', e.error.title);
      if (mounted) setState(() => _rejected = e);
    } catch (e) {
      Log.e('add configuration failed', '$e');
      if (mounted) showErrorDialog(context, describeError(e, subject: _subject()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A subscription can be added successfully and still be refused: the panel
  /// answers with placeholders instead of servers. The add succeeds (that is
  /// what the panel returned), and this is how the user learns why the list
  /// reads the way it does.
  ///
  /// Both handles are taken before the add, because adding the *first*
  /// configuration replaces this screen: the shell swaps in Home the moment a
  /// profile exists, and by the time there is anything to warn about, `ref`
  /// and `context` belong to a widget that is gone. The messenger is the root
  /// one, so the toast still lands on whatever the user is looking at.
  void _warnIfRefused(ProviderContainer container, ScaffoldMessengerState messenger) {
    final p = container.read(profilesControllerProvider).profiles.lastOrNull;
    if (p == null || !p.deviceLimitReached) return;
    showToastWith(messenger, kDeviceLimitReached.line);
  }

  Future<void> _continue() async {
    final t = _input.text.trim();
    final d = _detected;
    if (d == null) return;
    if (d.kind == InputKind.subscriptionUrl) {
      // Fetch as a subscription; when it isn't one, probe whether it's a
      // management server and hand over to sign-in instead of failing.
      final container = ProviderScope.containerOf(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _busy = true);
      try {
        await _ctrl.addSubscriptionUrl('', t);
        _warnIfRefused(container, messenger);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } on FormatException catch (fe) {
        try {
          await _ctrl.authConfig(t);
        } catch (_) {
          if (!mounted) return;
          // A panel that answered with something unusable gets the inline card;
          // anything else is a plain error.
          if (fe is SubscriptionFormatException) {
            setState(() => _rejected = fe);
          } else {
            showErrorDialog(context, describeError(fe, subject: _subject()));
          }
          return;
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SignInScreen(initialServer: t)),
          );
        }
      } catch (e) {
        Log.e('add subscription failed', '$e');
        if (mounted) showErrorDialog(context, describeError(e, subject: _subject()));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (d.kind == InputKind.amneziaKey) {
      // The key names a subscription; the servers are the gateway's to hand
      // out, so adding one is a network call and shows the same busy state a
      // subscription URL does.
      await _run(() async {
        await _ctrl.addAmneziaKey(t);
        return true;
      });
      return;
    }
    await _run(() async {
      await _ctrl.addFromText(t);
      return true;
    });
  }

  Future<void> _openFile() => _run(() async {
        final res = await FilePicker.platform.pickFiles(withData: true);
        if (res == null) return false; // cancelled — nothing added
        final bytes = res.files.single.bytes;
        if (bytes == null) {
          throw const AppErrorException(AppError('Couldn’t read the file',
              detail: 'Try opening it again, or paste its contents.'));
        }
        await _ctrl.addFromText(utf8.decode(bytes), name: res.files.single.name);
        return true;
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
                  if (_rejected != null) ...[
                    _RejectedCard(
                      failure: _rejected!,
                      onClose: () => setState(() => _rejected = null),
                    ),
                    const SizedBox(height: 14),
                  ],
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the panel answered with, when it was not servers.
///
/// A warning, not an error: nothing is broken on this device, and the text is
/// often the provider's own words. The action is the provider's page — the one
/// place where the format or the plan can actually be changed.
class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.failure, required this.onClose});

  final SubscriptionFormatException failure;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warn = context.vpnColors.connecting;
    final url = failure.openUrl;
    return Card(
      margin: EdgeInsets.zero,
      color: warn.withValues(alpha: 0.12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          leading: Icon(Icons.warning_amber_outlined, color: warn),
          title: Text(failure.error.title),
          subtitle: failure.error.detail == null ? null : Text(failure.error.detail!),
          isThreeLine: failure.error.detail != null,
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Dismiss',
            color: cs.onSurfaceVariant,
            onPressed: onClose,
          ),
        ),
        if (url != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Open subscription page'),
              onPressed: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
            ),
          ),
      ]),
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
