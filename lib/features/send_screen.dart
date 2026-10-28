import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/device_identity.dart';
import '../core/device_transfer.dart';
import '../core/ds.dart';
import '../core/log.dart';
import '../core/rule_set.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import '../state/session.dart';
import 'config/config_parts.dart';
import 'qr_scan_screen.dart';

Glyph transferDeviceGlyph(TransferDeviceKind kind) => switch (kind) {
  TransferDeviceKind.tv => Glyph.tv,
  TransferDeviceKind.desktop => Glyph.monitor,
  TransferDeviceKind.phone => Glyph.smartphone,
};

Future<TransferCode?> scanTransferCode(BuildContext context) async {
  final l10n = context.l10n;
  final text = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => QrScanScreen(
        title: l10n.transferScanTitle,
        headline: l10n.transferScanHint,
        hint: l10n.transferScanDetail,
        photos: false,
        refuse: (text) => TransferCode.parse(text) == null
            ? l10n.transferNotAReceiveCode
            : null,
      ),
    ),
  );
  return text == null ? null : TransferCode.parse(text);
}

Future<void> sendToAnotherDevice(BuildContext context) async {
  final code = await scanTransferCode(context);
  if (code == null || !context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SendScreen(code: code)));
}

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.code});

  final TransferCode code;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  late TransferCode _code = widget.code;
  late final Set<String> _picked = {
    for (final p in ref.read(profilesControllerProvider).profiles) p.id,
  };
  bool _ruleSets = true;
  bool _settings = true;
  bool _busy = false;
  int _setCount = 1;

  @override
  void initState() {
    super.initState();
    RuleSetStore.load().then((sets) {
      if (mounted) setState(() => _setCount = sets.length);
    });
  }

  bool get _vpnCarriesLan =>
      ref.watch(sessionProvider.select((s) => s.status)) ==
          VpnStatus.connected &&
      !ref.watch(routingPrefsProvider.select((p) => p.lanDirect));

  Future<void> _send() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final package = await buildTransferPackage(
        from: (await DeviceIdentityStore.load()).label,
        profileIds: _picked,
        allRuleSets: _ruleSets,
        settings: _settings,
      );
      await sendTransfer(_code, await sealTransfer(_code.publicKey, package));
      if (!mounted) return;
      showToast(context, l10n.transferSent(_code.name));
      Navigator.of(context).pop();
    } on TransferException catch (e) {
      if (!mounted) return;
      if (e.failure == TransferFailure.refused) {
        showToast(context, l10n.transferRefused(_code.name));
        final again = await scanTransferCode(context);
        if (again != null && mounted) setState(() => _code = again);
        return;
      }
      showErrorDialog(
        context,
        AppError(
          l10n.transferUnreachable(_code.name),
          detail: [
            l10n.transferUnreachableDetail,
            if (_vpnCarriesLan) l10n.transferUnreachableVpn,
          ].join(' '),
        ),
      );
    } catch (e) {
      Log.e('transfer: send failed', '$e');
      if (mounted) showErrorDialog(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DsCheck _check(bool on) => DsCheck(checked: on);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = ref.watch(profilesControllerProvider).profiles;
    final nothing = _picked.isEmpty && !_ruleSets && !_settings;
    return DsPage(
      title: l10n.transferSendTitle,
      dock: [
        DsButton(
          label: l10n.transferSendButton,
          busy: _busy,
          onPressed: nothing ? null : _send,
        ),
      ],
      children: [
        DsCard(
          children: [
            DsRow(
              glyph: transferDeviceGlyph(_code.kind),
              title: _code.name,
              subtitle: l10n.transferOnYourNetwork,
            ),
          ],
        ),
        DsNotification.warning(
          title: l10n.transferSameNetworkTitle,
          body: [
            l10n.transferSameNetworkBody,
            if (_vpnCarriesLan) l10n.transferVpnHint,
          ].join(' '),
        ),
        if (profiles.isNotEmpty)
          DsGroup(
            caption: l10n.settingsSectionConfigurations,
            children: [
              for (final p in profiles)
                DsRow(
                  glyph: profileIcon(p.type),
                  title: p.name,
                  subtitle: profileKind(p),
                  enabled: !_busy,
                  trailing: [_check(_picked.contains(p.id))],
                  onTap: _busy
                      ? null
                      : () => setState(
                          () => _picked.contains(p.id)
                              ? _picked.remove(p.id)
                              : _picked.add(p.id),
                        ),
                ),
            ],
          ),
        DsGroup(
          caption: l10n.transferAlso,
          children: [
            DsRow(
              glyph: Glyph.layers,
              title: l10n.ruleSetsTitle,
              subtitle: _ruleSets
                  ? l10n.settingsRuleSetCount(_setCount)
                  : l10n.transferRuleSetsUsedOnly,
              enabled: !_busy,
              trailing: [_check(_ruleSets)],
              onTap: _busy
                  ? null
                  : () => setState(() => _ruleSets = !_ruleSets),
            ),
            DsRow(
              glyph: Glyph.settings,
              title: l10n.commonSettings,
              subtitle: l10n.transferSettingsSubtitle,
              enabled: !_busy,
              trailing: [_check(_settings)],
              onTap: _busy
                  ? null
                  : () => setState(() => _settings = !_settings),
            ),
          ],
        ),
      ],
    );
  }
}
