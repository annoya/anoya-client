import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../core/ds.dart';
import '../core/log.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';

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
  late final Encode _code = zx.encodeBarcode(
    contents: widget.link,
    params: EncodeParams(
      format: Format.qrCode,
      width: 1,
      height: 1,
      eccLevel: EccLevel.medium,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _code;
    final ok =
        code.isValid &&
        code.data != null &&
        (code.width ?? 0) > 0 &&
        (code.height ?? 0) > 0;
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
                  child: CustomPaint(painter: _Modules(code)),
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

class _Modules extends CustomPainter {
  _Modules(this.code);

  final Encode code;

  @override
  void paint(Canvas canvas, Size size) {
    final w = code.width!;
    final h = code.height!;
    final data = code.data!;
    final cell = size.shortestSide / (w > h ? w : h);
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (data[y * w + x] < 128) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Modules old) => old.code != code;
}
