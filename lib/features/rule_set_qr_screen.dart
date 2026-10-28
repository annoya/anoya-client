import 'package:flutter/material.dart';

import '../core/ds.dart';
import '../core/log.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import 'qr_code_view.dart';

const kRuleSetQrMaxChars = 2331;

const double _kTileHeight = 348;
const double _kCodeSize = 328;

class RuleSetQrScreen extends StatefulWidget {
  const RuleSetQrScreen({
    super.key,
    required this.name,
    required this.ruleCount,
    required this.link,
  });

  final String name;
  final int ruleCount;
  final String link;

  @override
  State<RuleSetQrScreen> createState() => _RuleSetQrScreenState();
}

class _RuleSetQrScreenState extends State<RuleSetQrScreen> {
  late final _code = encodeQr(widget.link);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _code;
    final ok = qrUsable(code);
    if (!ok) Log.e('rule set QR not generated', code.error ?? 'no data');
    final ds = context.ds;
    return DsPage(
      leading: DsLeading.close,
      title: widget.name,
      gap: 16,
      children: [
        Container(
          height: _kTileHeight,
          margin: const EdgeInsets.only(top: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: ok
              ? SizedBox.square(
                  dimension: _kCodeSize,
                  child: CustomPaint(painter: QrModules(code)),
                )
              : Padding(
                  padding: const EdgeInsets.all(kCardPadding),
                  child: Text(
                    l10n.ruleSetExportQrTooLarge,
                    textAlign: TextAlign.center,
                    style: DsType.text.copyWith(color: Colors.black),
                  ),
                ),
        ),
        Text(
          '${widget.name} · ${l10n.ruleSetImportRules(widget.ruleCount)}',
          textAlign: TextAlign.center,
          style: DsType.h3.copyWith(color: ds.text1),
        ),
        DsNote(l10n.ruleSetQrHint, align: TextAlign.center),
      ],
    );
  }
}
