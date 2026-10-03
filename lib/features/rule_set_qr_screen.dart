import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../core/log.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

const kRuleSetQrMaxChars = 2331;

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
    return Scaffold(
      appBar: AppBar(leading: const CloseButton(), title: Text(widget.name)),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
          children: [
            Center(
              child: Container(
                width: kQrExportSize,
                height: kQrExportSize,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ok
                    ? CustomPaint(painter: _Modules(code))
                    : Center(
                        child: Text(
                          l10n.ruleSetExportQrTooLarge,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${widget.name} · ${l10n.ruleSetImportRules(widget.ruleCount)}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ruleSetQrHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
