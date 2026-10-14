import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

// '#' body, 'o' eye hole (the eye colour shows through), '*' glint.
const _kCatGrids = {
  CatFrame.off: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '####o##o####o##o####',
    '#####oo######oo#####',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
  CatFrame.lookL: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '####oo######oo######',
    '####ooo#####ooo#####',
    '####ooo#####ooo#####',
    '####ooo#####ooo#####',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
  CatFrame.lookR: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '######oo######oo####',
    '#####ooo#####ooo####',
    '#####ooo#####ooo####',
    '#####ooo#####ooo####',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
  CatFrame.on: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '#####oo######oo#####',
    '####o*oo####o*oo####',
    '####oooo####oooo####',
    '####oooo####oooo####',
    '####oooo####oooo####',
    '#####oo######oo#####',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
  CatFrame.happy: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '####################',
    '#####oo######oo#####',
    '####o##o####o##o####',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
  CatFrame.error: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '####o##o####o##o####',
    '#####oo######oo#####',
    '#####oo######oo#####',
    '####o##o####o##o####',
    '####################',
    '####################',
    '####################',
    '####################',
    '####################',
    '..################..',
    '..################..',
    '....############....',
    '....############....',
  ],
};

// Zzz on a 70×70 canvas: a big Z of 7 pt squares bottom left, a small one of 5 pt top right.
const _kZzzBig = [
  (0, 30), (7, 30), (14, 30), (21, 30), (28, 30), (21, 37), (14, 44), //
  (7, 51), (0, 58), (7, 58), (14, 58), (21, 58), (28, 58),
];
const _kZzzSmall = [
  (40, 0), (45, 0), (50, 0), (55, 0), (60, 0), (55, 5), (50, 10), //
  (45, 15), (40, 20), (45, 20), (50, 20), (55, 20), (60, 20),
];

enum CatFrame { off, lookL, lookR, on, happy, error }

enum CatMood { asleep, looking, awake, error }

const double kCatSize = 120;
const double kCatStageWidth = 240;
const double kCatStageHeight = 200;
const double kCatGlow = 240;
const double kCatGlowStrong = 260;
const double kCatGlowBlur = 80;
const Duration kCatLookFrame = Duration(milliseconds: 600);
const Duration kCatBlink = Duration(milliseconds: 200);
const Duration kCatPetSway = Duration(milliseconds: 140);
const Duration kCatPetHappy = Duration(milliseconds: 900);
const double kCatPetAngle = 8;

class CatPainter extends CustomPainter {
  CatPainter({
    required this.frame,
    required this.body,
    required this.eyes,
    this.glint = Colors.white,
  });

  final CatFrame frame;
  final Color body;
  final Color eyes;
  final Color glint;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _kCatGrids[frame]!;
    final cell = size.shortestSide / grid.length;
    final bodyPath = Path();
    final eyePath = Path();
    final glintPath = Path();
    for (var y = 0; y < grid.length; y++) {
      for (var x = 0; x < grid[y].length; x++) {
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        switch (grid[y][x]) {
          case '#':
            bodyPath.addRect(rect);
          case 'o':
            eyePath.addRect(rect);
          case '*':
            glintPath.addRect(rect);
        }
      }
    }
    canvas.drawPath(eyePath, Paint()..color = eyes);
    canvas.drawPath(bodyPath, Paint()..color = body);
    canvas.drawPath(glintPath, Paint()..color = glint);
  }

  @override
  bool shouldRepaint(CatPainter old) =>
      old.frame != frame || old.body != body || old.eyes != eyes;
}

class _ZzzPainter extends CustomPainter {
  _ZzzPainter(this.color, this.rise) : super(repaint: rise);

  final Color color;
  final ValueListenable<double> rise;

  @override
  void paint(Canvas canvas, Size size) {
    final lift = rise.value;
    final k = size.shortestSide / 70;
    void draw(List<(int, int)> cells, int side, double rise, double opacity) {
      final paint = Paint()..color = color.withValues(alpha: opacity);
      final path = Path();
      for (final (x, y) in cells) {
        path.addRect(Rect.fromLTWH(x * k, y * k - rise, side * k, side * k));
      }
      canvas.drawPath(path, paint);
    }

    draw(_kZzzBig, 7, lift * 2, 1 - lift * 0.3);
    draw(_kZzzSmall, 5, (1 - lift) * 2, 0.7 + lift * 0.3);
  }

  @override
  bool shouldRepaint(_ZzzPainter old) => old.color != color;
}

// catStage of the home hero: glow behind a 120 pt cat. Decorative — the status line speaks for it.
class CatStage extends StatefulWidget {
  const CatStage({
    super.key,
    required this.mood,
    this.strongGlow = false,
    this.glow = true,
    this.dimmed = false,
  });

  final CatMood mood;
  final bool strongGlow;
  final bool glow;
  final bool dimmed;

  @override
  State<CatStage> createState() => _CatStageState();
}

// One ticker drives every idle motion, so a covered or hidden home (TickerMode off) costs nothing.
class _CatStageState extends State<CatStage> with TickerProviderStateMixin {
  final _random = math.Random();
  final _zzzLift = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _petting = AnimationController(
    vsync: this,
    duration: kCatPetSway * 2 + kCatPetHappy,
  )..addListener(() => setState(() {}));
  bool _lookRight = false;
  bool _blinking = false;
  Duration _nextBlink = Duration.zero;
  Duration _blinkEnds = Duration.zero;
  bool _stillPet = false;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(CatStage old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _restart();
  }

  void _restart() {
    _ticker.stop();
    _lookRight = false;
    _blinking = false;
    _zzzLift.value = 0;
    _nextBlink = _blinkGap();
    if (widget.mood != CatMood.awake) _petting.reset();
    if (!_reduceMotion && widget.mood != CatMood.error) _ticker.start();
  }

  Duration _blinkGap() => Duration(milliseconds: 4000 + _random.nextInt(2000));

  void _onTick(Duration elapsed) {
    switch (widget.mood) {
      case CatMood.asleep:
        final t = elapsed.inMilliseconds / 2400;
        _zzzLift.value = (1 - math.cos(2 * math.pi * t)) / 2;
      case CatMood.looking:
        final right = (elapsed.inMilliseconds ~/ kCatLookFrame.inMilliseconds).isOdd;
        if (right != _lookRight) setState(() => _lookRight = right);
      case CatMood.awake:
        if (!_blinking && elapsed >= _nextBlink) {
          _blinkEnds = elapsed + kCatBlink;
          setState(() => _blinking = true);
        } else if (_blinking && elapsed >= _blinkEnds) {
          _nextBlink = elapsed + _blinkGap();
          setState(() => _blinking = false);
        }
      case CatMood.error:
        break;
    }
  }

  // Petting: ±8° twice by 140 ms, then happy for 0.9 s. Reduce Motion keeps only the happy face.
  void _pet() {
    if (widget.mood != CatMood.awake || _petting.isAnimating) return;
    _stillPet = _reduceMotion;
    _petting.forward(from: 0);
  }

  Duration get _petAt => _petting.duration! * _petting.value;

  bool get _petActive => _petting.isAnimating;

  double get _sway {
    if (!_petActive || _stillPet) return 0;
    final at = _petAt;
    if (at < kCatPetSway) return -kCatPetAngle;
    if (at < kCatPetSway * 2) return kCatPetAngle;
    return 0;
  }

  bool get _petHappy =>
      _petActive && (_stillPet || _petAt >= kCatPetSway * 2);

  @override
  void dispose() {
    _ticker.dispose();
    _petting.dispose();
    _zzzLift.dispose();
    super.dispose();
  }

  CatFrame get _frame => switch (widget.mood) {
    CatMood.asleep => CatFrame.off,
    CatMood.looking => _lookRight ? CatFrame.lookR : CatFrame.lookL,
    CatMood.error => CatFrame.error,
    CatMood.awake => _blinking || _petHappy ? CatFrame.happy : CatFrame.on,
  };

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final glowSize = widget.strongGlow ? kCatGlowStrong : kCatGlow;
    final reach = glowSize + kCatGlowBlur * 2;
    final cat = CustomPaint(
      size: const Size.square(kCatSize),
      painter: CatPainter(frame: _frame, body: ds.text1, eyes: ds.chroma),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: kCatStageWidth,
        height: kCatStageHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.glow)
              Positioned(
                left: (kCatStageWidth - reach) / 2,
                top: (kCatStageHeight - reach) / 2,
                width: reach,
                height: reach,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ds.accentAlpha,
                          ds.accentAlpha,
                          ds.accentAlpha.withValues(alpha: 0),
                        ],
                        stops: [0, glowSize / reach * 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            Opacity(
              opacity: widget.dimmed ? kDisabledOpacity : 1,
              child: MouseRegion(
                cursor: widget.mood == CatMood.awake
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                onEnter: (_) => _pet(),
                child: GestureDetector(
                  onTap: _pet,
                  child: SizedBox.square(
                    dimension: kCatSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Transform.rotate(
                          angle: _sway * math.pi / 180,
                          child: cat,
                        ),
                        if (widget.mood == CatMood.asleep)
                          Positioned(
                            left: 105.6,
                            top: -26.4,
                            width: 42,
                            height: 42,
                            child: CustomPaint(
                              painter: _ZzzPainter(ds.accent, _zzzLift),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
