import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/app_error.dart';
import '../core/device_transfer.dart';
import '../core/ds.dart';
import '../core/log.dart';
import '../core/parsers/qr_payload.dart';
import '../core/parsers/subscription.dart';
import '../core/platform_support.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import 'qr_scan_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
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

  void _onChanged(String v, {bool complete = false}) {
    _verdictTimer?.cancel();
    setState(() {
      _detected = detectInput(v);
      _rejected = null;
      _verdict = complete && _detected == null && v.trim().isNotEmpty
          ? whyUnusable(v)
          : null;
    });
    if (!complete && _detected == null && v.trim().isNotEmpty) {
      _verdictTimer = Timer(_verdictDelay, () {
        if (!mounted || _input.text != v) return;
        setState(() => _verdict = whyUnusable(v));
      });
    }
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      showToast(context, context.l10n.startClipboardEmpty);
      return;
    }
    _fill(unwrapImportLink(text));
  }

  Future<void> _scanQr() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(
          refuse: (text) => TransferCode.parse(text) != null
              ? null
              : QrScanScreen.refuseUnlessConnection(text),
        ),
      ),
    );
    if (text == null || !mounted) return;
    if (TransferCode.parse(text) case final code?) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SendScreen(code: code)));
      return;
    }
    _fill(text);
  }

  void _receive() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ReceiveScreen()));

  void _fill(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onChanged(text, complete: true);
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
    final ds = context.ds;
    final rejected = _rejected;
    final helper =
        _detected?.label ??
        (_verdict == null ? null : l10n.startCantUseThis(_verdict!));
    return DsPage(
      title: l10n.startAddConnection,
      subtitle: l10n.startSubtitle,
      children: [
        if (rejected != null) _Rejected(failure: rejected),
        if (rejected?.openUrl != null)
          DsButton.secondary(
            label: l10n.startOpenSubscriptionPage,
            glyph: Glyph.link,
            onPressed: () => launchUrl(
              Uri.parse(rejected!.openUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              enabled: !_busy,
              onChanged: _onChanged,
              decoration: InputDecoration(
                labelText: l10n.startLinkLabel,
                hintText: l10n.startLinkHint,
                suffixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  child: DsAction(
                    glyph: Glyph.clipboard,
                    size: kFieldActionButton,
                    tooltip: l10n.startPaste,
                    color: _busy
                        ? ds.icon1.withValues(alpha: kDisabledOpacity)
                        : null,
                    onPressed: _busy ? null : _paste,
                  ),
                ),
              ),
            ),
            if (helper != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  helper,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DsType.small.copyWith(
                    color: _detected == null ? ds.destructive : ds.text3,
                  ),
                ),
              ),
          ],
        ),
        DsStack(
          children: [
            DsButton(
              label: l10n.commonContinue,
              busy: _busy,
              onPressed: _detected == null ? null : _continue,
            ),
            if (canScanQr)
              DsButton.secondary(
                label: l10n.startScanQr,
                glyph: Glyph.scan,
                onPressed: _busy ? null : _scanQr,
              ),
            if (canOpenFiles)
              DsButton.secondary(
                label: l10n.startOpenConfigFile,
                glyph: Glyph.folder,
                onPressed: _busy ? null : _openFile,
              ),
            DsButton.secondary(
              label: l10n.transferReceive,
              glyph: Glyph.smartphone,
              autofocus: isTv,
              onPressed: _busy ? null : _receive,
            ),
            _OrDivider(l10n.startOr),
            DsButton.tonal(
              label: l10n.startSignInToServer,
              glyph: Glyph.briefcase,
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignInScreen()),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Rejected extends StatelessWidget {
  const _Rejected({required this.failure});

  final SubscriptionFormatException failure;

  @override
  Widget build(BuildContext context) => DsNotification.warning(
    title: failure.error.title,
    body: failure.error.detail,
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final line = Expanded(child: Container(height: 1, color: ds.borderFaint));
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: DsType.caption.copyWith(color: ds.text3)),
          ),
          line,
        ],
      ),
    );
  }
}
