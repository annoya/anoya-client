import 'dart:async';
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
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import 'sign_in_screen.dart';

class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final _input = TextEditingController();
  DetectedInput? _detected;
  bool _busy = false;

  String? _verdict;
  Timer? _verdictTimer;
  static const _verdictDelay = Duration(milliseconds: 700);

  @override
  void dispose() {
    _verdictTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  String? _subject() {
    final text = _input.text.trim();
    if (!text.startsWith('http')) return null;
    return Uri.tryParse(text)?.host.isNotEmpty == true
        ? Uri.parse(text).host
        : null;
  }

  SubscriptionFormatException? _rejected;

  void _onChanged(String v) {
    _verdictTimer?.cancel();
    setState(() {
      _detected = detectInput(v);
      _rejected = null;
      _verdict = null;
    });
    if (_detected == null && v.trim().isNotEmpty) {
      _verdictTimer = Timer(_verdictDelay, () {
        if (!mounted || _input.text != v) return;
        setState(() => _verdict = whyUnusable(v));
      });
    }
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      final added = await action();
      if (added && mounted) {
        _warnIfRefused();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on SubscriptionFormatException catch (e) {
      Log.e('add configuration rejected', e.error.title);
      if (mounted) setState(() => _rejected = e);
    } catch (e) {
      Log.e('add configuration failed', '$e');
      if (mounted) {
        showErrorDialog(context, describeError(e, subject: _subject()));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _warnIfRefused() {
    final p = ref.read(profilesControllerProvider).profiles.lastOrNull;
    if (p == null || !p.deviceLimitReached) return;
    showToast(context, kDeviceLimitReached.line);
  }

  Future<void> _continue() async {
    final t = _input.text.trim();
    final d = _detected;
    if (d == null) return;
    if (d.kind == InputKind.subscriptionUrl) {
      setState(() => _busy = true);
      try {
        await _ctrl.addSubscriptionUrl('', t);
        if (mounted) {
          _warnIfRefused();
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      } on FormatException catch (fe) {
        try {
          await _ctrl.authConfig(t);
        } catch (_) {
          if (!mounted) return;
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
        if (mounted) {
          showErrorDialog(context, describeError(e, subject: _subject()));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (d.kind == InputKind.amneziaKey) {
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
    if (res == null) return false;
    final bytes = res.files.single.bytes;
    if (bytes == null) {
      throw AppErrorException(
        AppError(
          L10n.current.startCouldntReadFile,
          detail: L10n.current.startCouldntReadFileDetail,
        ),
      );
    }
    await _ctrl.addFromText(utf8.decode(bytes), name: res.files.single.name);
    return true;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
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
                  Text(
                    l10n.startAddConnection,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.startSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
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
                    decoration: InputDecoration(
                      labelText: l10n.startLinkLabel,
                      hintText: l10n.startLinkHint,
                    ),
                  ),
                  if (_detected != null) ...[
                    const SizedBox(height: 10),
                    _DetectChip(text: _detected!.label),
                  ] else if (_verdict != null) ...[
                    const SizedBox(height: 10),
                    _DetectChip(
                      text: l10n.startCantUseThis(_verdict!),
                      refused: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: (_busy || _detected == null) ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.commonContinue),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(l10n.startOpenConfigFile),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          l10n.startOr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignInScreen(),
                            ),
                          ),
                    icon: const Icon(Icons.business_outlined, size: 18),
                    label: Text(l10n.startSignInToServer),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.warning_amber_outlined, color: warn),
            title: Text(failure.error.title),
            subtitle: failure.error.detail == null
                ? null
                : Text(failure.error.detail!),
            isThreeLine: failure.error.detail != null,
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: context.l10n.commonDismiss,
              color: cs.onSurfaceVariant,
              onPressed: onClose,
            ),
          ),
          if (url != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link, size: 18),
                label: Text(context.l10n.startOpenSubscriptionPage),
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetectChip extends StatelessWidget {
  const _DetectChip({required this.text, this.refused = false});
  final String text;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warn = context.vpnColors.connecting;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: refused
            ? warn.withValues(alpha: 0.14)
            : cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (refused ? warn : cs.primary).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            refused ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: refused ? warn : cs.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: refused ? cs.onSurface : cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
