import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/device_identity.dart';
import '../core/device_transfer.dart';
import '../core/ds.dart';
import '../core/log.dart';
import '../core/network_extension_core.dart';
import '../core/platform_support.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/transfer_inbox.dart';
import 'config/config_parts.dart';
import 'qr_code_view.dart';

const kReceiveNetworkPoll = Duration(seconds: 3);

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  TransferReceiver? _receiver;
  TransferPackage? _package;
  bool _noNetwork = false;
  bool _adding = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _keepScreenOn(true);
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _receiver?.close();
    _keepScreenOn(false);
    super.dispose();
  }

  void _keepScreenOn(bool on) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    NetworkExtensionCore.control
        .invoke<void>('keep_screen_on', {'on': on})
        .catchError((Object e) => Log.e('transfer: screen stays dim', '$e'));
  }

  Future<void> _start() async {
    _poll?.cancel();
    final addresses = await localTransferAddresses();
    if (!mounted) return;
    if (addresses.isEmpty) {
      setState(() => _noNetwork = true);
      _poll = Timer(kReceiveNetworkPoll, _start);
      return;
    }
    final TransferReceiver receiver;
    try {
      receiver = await TransferReceiver.start(
        name: (await DeviceIdentityStore.load()).label,
        kind: isTv
            ? TransferDeviceKind.tv
            : isDesktop
            ? TransferDeviceKind.desktop
            : TransferDeviceKind.phone,
        addresses: addresses,
      );
    } catch (e) {
      Log.e('transfer: receiver not started', '$e');
      if (!mounted) return;
      final l10n = context.l10n;
      await showErrorDialog(
        context,
        AppError(
          l10n.transferCouldntListen,
          detail: l10n.transferCouldntListenDetail('$e'),
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) {
      await receiver.close();
      return;
    }
    setState(() {
      _noNetwork = false;
      _receiver = receiver;
    });
    final package = await receiver.received;
    if (mounted) setState(() => _package = package);
  }

  Future<void> _add() async {
    final package = _package;
    if (package == null) return;
    setState(() => _adding = true);
    try {
      await ref.read(transferInboxProvider).add(package);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      Log.e('transfer: adding failed', '$e');
      if (!mounted) return;
      setState(() => _adding = false);
      showErrorDialog(
        context,
        AppError(context.l10n.transferAddFailed, detail: describeError(e).line),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = isWideLandscape(MediaQuery.sizeOf(context));
    final package = _package;
    final receiver = _receiver;
    if (package != null) {
      return wide ? _arrivedWide(package) : _arrivedNarrow(package);
    }
    if (_noNetwork) {
      return DsPage(
        title: l10n.transferReceive,
        body: Center(
          child: DsEmptyState(
            glyph: Glyph.wifi,
            heading: l10n.transferNoNetwork,
            title: l10n.transferNoNetworkDetail,
          ),
        ),
      );
    }
    if (receiver == null) {
      return DsPage(
        title: l10n.transferReceive,
        body: const Center(child: DsSpinner()),
      );
    }
    final code = receiver.code.toLink();
    if (!wide) {
      return DsPage(
        title: l10n.transferReceive,
        children: [
          _CodeTile(code, tile: kTransferTileSmall, size: kTransferCodeSmall),
          const _Steps(gap: 8),
          DsNote(l10n.transferReceiveNote),
        ],
      );
    }
    return _widePage(
      Center(
        child: Row(
          children: [
            _CodeTile(code, tile: kTransferTile, size: kTransferCode),
            const SizedBox(width: kWideColumnGap),
            Expanded(
              child: DsStack(
                children: [
                  const _Steps(gap: 12),
                  DsNote(l10n.transferReceiveNote),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _widePage(Widget body) => Scaffold(
    appBar: DsNavBar(title: context.l10n.transferReceive),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: body,
    ),
  );

  Widget _from(TransferPackage package, TextStyle style) => Row(
    children: [
      const GlyphIcon(Glyph.smartphone),
      const SizedBox(width: kRowGap),
      Expanded(
        child: Text(
          context.l10n.transferFrom(package.from),
          style: style.copyWith(color: context.ds.text1),
        ),
      ),
    ],
  );

  List<Widget> _buttons() => [
    DsButton(
      label: context.l10n.commonAdd,
      busy: _adding,
      autofocus: isTv || isDesktop,
      onPressed: _add,
    ),
    DsButton.secondary(
      label: context.l10n.commonCancel,
      onPressed: _adding ? null : () => Navigator.of(context).pop(),
    ),
  ];

  Widget _arrivedNarrow(TransferPackage package) => DsPage(
    title: context.l10n.transferReceive,
    dock: _buttons(),
    children: [
      _from(package, DsType.h3),
      _Arrived(package),
      DsNote(context.l10n.transferConfirmNoteShort),
    ],
  );

  Widget _arrivedWide(TransferPackage package) => _widePage(
    Padding(
      padding: const EdgeInsets.only(top: kGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kWideSideColumn,
            child: DsStack(
              gap: kGroupGap,
              children: [
                _from(package, DsType.h2),
                DsNote(context.l10n.transferConfirmNote),
                DsStack(children: _buttons()),
              ],
            ),
          ),
          const SizedBox(width: kWideColumnGap),
          Expanded(child: SingleChildScrollView(child: _Arrived(package))),
        ],
      ),
    ),
  );
}

class _CodeTile extends StatelessWidget {
  const _CodeTile(this.data, {required this.tile, required this.size});

  final String data;
  final double tile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = encodeQr(data);
    return Center(
      child: Container(
        width: tile,
        height: tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: qrUsable(code)
            ? SizedBox.square(
                dimension: size,
                child: CustomPaint(painter: QrModules(code)),
              )
            : null,
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.gap});

  final double gap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ds = context.ds;
    final steps = [
      l10n.transferStepOpen,
      l10n.transferStepSettings,
      l10n.transferStepScan,
    ];
    return DsStack(
      gap: gap,
      children: [
        for (final (i, step) in steps.indexed)
          Row(
            children: [
              Container(
                width: kTransferStepBadge,
                height: kTransferStepBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ds.selected,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: DsType.small.copyWith(
                    color: ds.textAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: kRowGap),
              Expanded(
                child: Text(step, style: DsType.h3.copyWith(color: ds.text1)),
              ),
            ],
          ),
        Padding(
          padding: EdgeInsets.only(top: gap),
          child: Row(
            children: [
              DsSpinner(color: ds.accent),
              const SizedBox(width: kRowGap),
              Text(
                l10n.transferWaiting,
                style: DsType.text.copyWith(color: ds.text2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Arrived extends ConsumerWidget {
  const _Arrived(this.package);

  final TransferPackage package;

  String _kind(String type) {
    final l10n = L10n.current;
    return switch (ProfileType.values.asNameMap()[type]) {
      ProfileType.selfhosted => l10n.transferKindSelfhosted,
      ProfileType.amnezia => l10n.transferKindKey,
      ProfileType.link => l10n.configKindSingleServer,
      _ => l10n.configKindSubscriptionPlain,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final inbox = ref.read(transferInboxProvider);
    return DsCard(
      children: [
        for (final p in package.profiles)
          DsRow(
            glyph: profileIcon(
              ProfileType.values.asNameMap()[p['type']] ??
                  ProfileType.subscription,
            ),
            title: '${p['name'] ?? ''}',
            subtitle: inbox.isKnown(p['id'] as String)
                ? l10n.transferItemUpdates(_kind('${p['type']}'))
                : l10n.transferItemNew(_kind('${p['type']}')),
          ),
        if (package.ruleSets.isNotEmpty)
          DsRow(
            glyph: Glyph.layers,
            title: l10n.ruleSetsTitle,
            subtitle: l10n.settingsRuleSetCount(package.ruleSets.length),
          ),
        if (package.hasSettings)
          DsRow(
            glyph: Glyph.settings,
            title: l10n.commonSettings,
            subtitle: l10n.transferSettingsSubtitle,
          ),
      ],
    );
  }
}
