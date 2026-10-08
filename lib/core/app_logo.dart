import 'package:flutter/material.dart';

const _kLogoGrid = [
  '##......##',
  '###....###',
  '##########',
  '##..##..##',
  '##..##..##',
  '##..##..##',
  '##########',
  '##########',
  '.########.',
  '..######..',
];

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _LogoPainter(
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      ),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _kLogoGrid.length;
    final path = Path();
    for (var y = 0; y < _kLogoGrid.length; y++) {
      final row = _kLogoGrid[y];
      var x = 0;
      while (x < row.length) {
        if (row[x] != '#') {
          x++;
          continue;
        }
        final start = x;
        while (x < row.length && row[x] == '#') {
          x++;
        }
        path.addRect(
          Rect.fromLTWH(start * cell, y * cell, (x - start) * cell, cell),
        );
      }
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
