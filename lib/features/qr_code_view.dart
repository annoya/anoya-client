import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Encode encodeQr(String contents) => zx.encodeBarcode(
  contents: contents,
  params: EncodeParams(
    format: Format.qrCode,
    width: 1,
    height: 1,
    eccLevel: EccLevel.medium,
  ),
);

bool qrUsable(Encode code) =>
    code.isValid &&
    code.data != null &&
    (code.width ?? 0) > 0 &&
    (code.height ?? 0) > 0;

class QrModules extends CustomPainter {
  QrModules(this.code);

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
  bool shouldRepaint(QrModules old) => old.code != code;
}
