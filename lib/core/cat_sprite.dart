import 'dart:async';
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
  CatFrame.peek: [
    '####............####',
    '####............####',
    '######........######',
    '######........######',
    '####################',
    '####################',
    '####################',
    '####################',
    '############oooo####',
    '####o##o####o*oo####',
    '#####oo#####oooo####',
    '#############oo#####',
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

const _kHeart = [
  '.aa.aa.',
  'aaaaaaa',
  'aaaaaaa',
  '.aaaaa.',
  '..aaa..',
  '...a...',
];
const _kStar = ['..w..', '.www.', 'wwwww', '.www.', '..w..'];
const _kIron = [
  '..........aaaaaa....',
  '.........a......a...',
  '........a.......a...',
  '.......aaaaaaaaaaaa.',
  '.....aaaaaaaaaaaaaa.',
  '...aaaaaaaaaaaaaaaa.',
  '.aaaaaaaaaaaaaaaaaa.',
  'aaaaaaaaaaaaaaaaaaa.',
  'wwwwwwwwwwwwwwwwwww.',
];
const _kCatFlat = ['ww........ww', 'wwwwwwwwwwww', 'wweewwwweeww'];

enum CatFrame { off, lookL, lookR, on, happy, peek, error }

enum CatMood { asleep, looking, awake, error }

const double kCatSize = 120;
const double kCatStageWidth = 240;
const double kCatStageHeight = 200;
const double kCatGlow = 240;
const double kCatGlowStrong = 260;
const double kCatGlowBlur = 80;
const double kCatGlowMutedOpacity = 0.35;
const Duration kCatLookFrame = Duration(milliseconds: 600);
const Duration kCatBlink = Duration(milliseconds: 200);

const double kCatPetAngle = 8;
const double kCatPetScale = 1.07;
const Duration kCatPetSwingIn = Duration(milliseconds: 150);
const Duration kCatPetSwing = Duration(milliseconds: 200);
const Duration kCatPetSettle = Duration(milliseconds: 150);
const Duration kCatPetScaleIn = Duration(milliseconds: 200);
const Duration kCatPetScaleOut = Duration(milliseconds: 300);
const Duration kCatPetHold = Duration(milliseconds: 400);
const Duration kCatHappyStill = Duration(milliseconds: 900);
const int kCatHeartsTap = 5;
const int kCatIronTap = 15;
const Duration kCatPeek = Duration(milliseconds: 600);
const double kCatPeekHop = 6;

const Duration _kIronAct = Duration(milliseconds: 2950);
const Duration _kHideAct = Duration(milliseconds: 1500);

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

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.grid, this.colors);

  final List<String> grid;
  final Map<String, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / grid.first.length;
    for (final MapEntry(key: ch, value: color) in colors.entries) {
      final path = Path();
      for (var y = 0; y < grid.length; y++) {
        for (var x = 0; x < grid[y].length; x++) {
          if (grid[y][x] == ch) {
            path.addRect(Rect.fromLTWH(x * cell, y * cell, cell, cell));
          }
        }
      }
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.grid != grid || !mapEquals(old.colors, colors);
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

class _Heart {
  const _Heart(this.born, this.at, this.drift, {required this.big});

  final Duration born;
  final Offset at;
  final double drift;
  final bool big;

  Duration get life => Duration(milliseconds: big ? 800 : 700);
  double get rise => big ? 70 : 55;
}

const _kBurst = [
  (Offset(20, -30), -9.1),
  (Offset(46, -40), 0.0),
  (Offset(72, -30), 9.1),
];
const _kSingles = [(Offset(33, -30), -4.55), (Offset(59, -40), 4.55)];
const _kSingleGap = Duration(milliseconds: 100);

enum _Act { none, iron, hide }

double _track(double ms, List<(double, double, Curve)> keys) {
  if (ms <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    final (t, v, curve) = keys[i];
    if (ms <= t) {
      final (t0, v0, _) = keys[i - 1];
      return v0 + (v - v0) * curve.transform((ms - t0) / (t - t0));
    }
  }
  return keys.last.$2;
}

double _ms(Duration d) => d.inMicroseconds / 1000;

// catStage of the home hero: glow behind a 120 pt cat. Decorative — the status line speaks for it.
class CatStage extends StatefulWidget {
  const CatStage({
    super.key,
    required this.mood,
    this.strongGlow = false,
    this.dimmed = false,
  });

  final CatMood mood;
  final bool strongGlow;
  final bool dimmed;

  static bool _ironed = false;
  static bool _hideNext = true;

  @visibleForTesting
  static void resetForTests() {
    _ironed = false;
    _hideNext = true;
  }

  @override
  State<CatStage> createState() => _CatStageState();
}

class _CatStageState extends State<CatStage> with TickerProviderStateMixin {
  final _random = math.Random();
  final _zzzLift = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Timer? _settle;
  Timer? _beat;

  bool _lookRight = false;
  bool _blinking = false;

  int _taps = 0;
  Duration? _petFrom;
  Duration _lastTap = Duration.zero;
  Duration? _released;
  double _releasedAngle = 0;
  double _releasedScale = 1;
  Duration? _lastSingle;
  final _hearts = <_Heart>[];
  _Act _act = _Act.none;
  Duration _actFrom = Duration.zero;
  Duration? _peekFrom;
  Duration? _happyUntil;

  Duration get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  bool? _stillMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stillMotion == _reduceMotion) return;
    _stillMotion = _reduceMotion;
    _restart();
  }

  @override
  void didUpdateWidget(CatStage old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _restart();
  }

  void _restart() {
    _ticker.stop();
    _beat?.cancel();
    _lookRight = false;
    _blinking = false;
    _zzzLift.value = 0;
    _taps = 0;
    _petFrom = null;
    _released = null;
    _hearts.clear();
    _act = _Act.none;
    _peekFrom = null;
    _happyUntil = null;
    if (_reduceMotion) return;
    switch (widget.mood) {
      case CatMood.asleep:
        _ticker.start();
      case CatMood.looking:
        _beat = Timer.periodic(kCatLookFrame, (_) {
          setState(() => _lookRight = !_lookRight);
        });
      case CatMood.awake:
        _scheduleBlink();
      case CatMood.error:
        break;
    }
  }

  Duration _blinkGap() => Duration(milliseconds: 4000 + _random.nextInt(2000));

  void _scheduleBlink() {
    _beat = Timer(_blinkGap(), () {
      setState(() => _blinking = true);
      _beat = Timer(kCatBlink, () {
        setState(() => _blinking = false);
        _scheduleBlink();
      });
    });
  }

  void _onTick(Duration elapsed) {
    switch (widget.mood) {
      case CatMood.asleep:
        final t = elapsed.inMilliseconds / 2400;
        _zzzLift.value = (1 - math.cos(2 * math.pi * t)) / 2;
        if (_peekFrom != null) setState(_expire);
      case CatMood.awake:
        setState(_expire);
        if (!_busy) _ticker.stop();
      case CatMood.looking || CatMood.error:
        break;
    }
  }

  bool get _busy =>
      _petFrom != null ||
      _released != null ||
      _hearts.isNotEmpty ||
      _act != _Act.none;

  void _expire() {
    final now = _now;
    if (_petFrom != null && now - _lastTap > kCatPetHold) _release(now);
    if (_released case final r? when now - r > kCatPetScaleOut) {
      _released = null;
    }
    _hearts.removeWhere((h) => now - h.born > h.life);
    final actLength = _act == _Act.iron ? _kIronAct : _kHideAct;
    if (_act != _Act.none && now - _actFrom > actLength) _act = _Act.none;
    if (_peekFrom case final p? when now - p > kCatPeek) _peekFrom = null;
    if (_happyUntil case final u? when now >= u) _happyUntil = null;
  }

  void _release(Duration at) {
    if (_petFrom == null) return;
    _releasedAngle = _loopAngle(at);
    _releasedScale = _loopScale(at);
    _released = at;
    _petFrom = null;
    _taps = 0;
  }

  void _tap() {
    if (_ticker.isActive) return _onTap();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) _onTap();
    });
  }

  void _onTap() {
    switch (widget.mood) {
      case CatMood.awake:
        _pet();
      case CatMood.asleep:
        _peek();
      case CatMood.looking || CatMood.error:
        break;
    }
  }

  void _peek() {
    if (_peekFrom != null) return;
    setState(() => _peekFrom = _now);
    if (_reduceMotion) _later(kCatPeek, () => _peekFrom = null);
  }

  void _pet() {
    if (_act != _Act.none) return;
    final now = _now;
    if (_reduceMotion) {
      setState(() => _happyUntil = now + kCatHappyStill);
      _later(kCatHappyStill, () => _happyUntil = null);
      return;
    }
    _expire();
    if (_petFrom == null) {
      _petFrom = now;
      _released = null;
      _taps = 0;
    }
    _taps++;
    _lastTap = now;
    if (_taps == kCatHeartsTap) {
      _burst(now);
    } else if (_taps > kCatHeartsTap && _taps < kCatIronTap) {
      _single(now);
    } else if (_taps == kCatIronTap) {
      if (!CatStage._ironed) {
        CatStage._ironed = true;
        _startAct(_Act.iron, now);
      } else {
        if (CatStage._hideNext) _startAct(_Act.hide, now);
        CatStage._hideNext = !CatStage._hideNext;
        _taps = 0;
      }
    }
    setState(() {});
    if (!_ticker.isActive) _ticker.start();
  }

  void _later(Duration after, VoidCallback done) {
    _settle?.cancel();
    _settle = Timer(after, () {
      if (mounted) setState(done);
    });
  }

  void _startAct(_Act act, Duration now) {
    _release(now);
    _act = act;
    _actFrom = now;
  }

  void _burst(Duration at) {
    for (final (i, (offset, drift)) in _kBurst.indexed) {
      _hearts.add(
        _Heart(at + Duration(milliseconds: 50 * i), offset, drift, big: true),
      );
    }
  }

  void _single(Duration at) {
    if (_lastSingle case final l? when at - l < _kSingleGap) return;
    final (offset, drift) = _kSingles[_taps.isEven ? 0 : 1];
    _hearts.add(_Heart(at, offset, drift, big: false));
    _lastSingle = at;
  }

  double _loopAngle(Duration at) {
    final t = _ms(at - _petFrom!);
    final swingIn = _ms(kCatPetSwingIn);
    if (t < swingIn) {
      return kCatPetAngle * Curves.easeOut.transform(t / swingIn);
    }
    final swing = _ms(kCatPetSwing);
    final k = (t - swingIn) ~/ swing;
    final from = k.isEven ? kCatPetAngle : -kCatPetAngle;
    final f = ((t - swingIn) % swing) / swing;
    return from - 2 * from * Curves.easeInOut.transform(f);
  }

  double _loopScale(Duration at) {
    final t = _ms(at - _petFrom!) / _ms(kCatPetScaleIn);
    return 1 + (kCatPetScale - 1) * Curves.easeOut.transform(t.clamp(0, 1));
  }

  double get _angle {
    final now = _now;
    if (_act == _Act.iron) {
      final shake = _track(_ms(now - _actFrom), const [
        (2150, 0, Curves.linear),
        (2210, 10, Curves.easeInOut),
        (2280, -10, Curves.easeInOut),
        (2350, 7, Curves.easeInOut),
        (2410, -5, Curves.easeInOut),
        (2450, 0, Curves.easeOut),
      ]);
      if (shake != 0) return shake;
    }
    if (_petFrom != null) return _loopAngle(now);
    if (_released case final r?) {
      final u = (_ms(now - r) / _ms(kCatPetSettle)).clamp(0.0, 1.0);
      return _releasedAngle * (1 - Curves.easeOut.transform(u));
    }
    return 0;
  }

  double get _scale {
    final now = _now;
    if (_petFrom != null) return _loopScale(now);
    if (_released case final r?) {
      final u = (_ms(now - r) / _ms(kCatPetScaleOut)).clamp(0.0, 1.0);
      return 1 + (_releasedScale - 1) * (1 - Curves.easeOut.transform(u));
    }
    return 1;
  }

  double get _drop {
    if (_act != _Act.hide) return 0;
    return _track(_ms(_now - _actFrom), const [
      (0, 0, Curves.linear),
      (250, 24, Curves.easeIn),
      (400, 42, Curves.easeOut),
      (1200, 42, Curves.linear),
      (1500, 0, Curves.easeOut),
    ]);
  }

  double get _hop {
    final p = _peekFrom;
    if (p == null || _reduceMotion) return 0;
    return -_track(_ms(_now - p), const [
      (0, 0, Curves.linear),
      (100, kCatPeekHop, Curves.easeOut),
      (200, 0, Curves.easeOut),
    ]);
  }

  bool get _petHappy {
    if (_happyUntil case final u? when _now < u) return true;
    if (_petFrom != null) return true;
    final r = _released;
    return r != null && _now - r < kCatPetSettle && _act == _Act.none;
  }

  CatFrame get _frame {
    if (widget.mood == CatMood.awake && _act != _Act.none) {
      final t = _ms(_now - _actFrom);
      if (_act == _Act.hide) {
        if (t < 400 || t >= 1200) return CatFrame.on;
        return t < 800 ? CatFrame.lookL : CatFrame.lookR;
      }
      if (t < 1550) return CatFrame.on;
      if (t < 2450) return CatFrame.error;
      if (t < 2950) return CatFrame.happy;
    }
    return switch (widget.mood) {
      CatMood.asleep => _peekFrom != null ? CatFrame.peek : CatFrame.off,
      CatMood.looking => _lookRight ? CatFrame.lookR : CatFrame.lookL,
      CatMood.error => CatFrame.error,
      CatMood.awake => _blinking || _petHappy ? CatFrame.happy : CatFrame.on,
    };
  }

  bool get _flat {
    if (_act != _Act.iron) return false;
    final t = _ms(_now - _actFrom);
    return t >= 250 && t < 1550;
  }

  @override
  void dispose() {
    _settle?.cancel();
    _beat?.cancel();
    _ticker.dispose();
    _zzzLift.dispose();
    super.dispose();
  }

  Widget _sprite(
    List<String> grid,
    double cell,
    Map<String, Color> colors, {
    Key? key,
  }) => CustomPaint(
    key: key,
    size: Size(grid.first.length * cell, grid.length * cell),
    painter: _PixelPainter(grid, colors),
  );

  List<Widget> _props(DsColors ds) {
    final now = _now;
    final ink = {'a': ds.accent};
    final props = <Widget>[];
    for (final h in _hearts) {
      final p = _ms(now - h.born) / _ms(h.life);
      if (p < 0 || p > 1) continue;
      final up = Curves.easeOut.transform(p);
      final fade = p < 0.55
          ? 1.0
          : 1 - Curves.easeIn.transform((p - 0.55) / 0.45);
      props.add(
        Positioned(
          left: h.at.dx + h.drift * up,
          top: h.at.dy - h.rise * up,
          child: Opacity(
            opacity: fade.clamp(0, 1),
            child: _sprite(_kHeart, 4, ink, key: const ValueKey('cat-heart')),
          ),
        ),
      );
    }
    if (_act != _Act.iron) return props;
    final t = _ms(now - _actFrom);
    if (_flat) {
      props.add(
        Positioned(
          left: -12,
          top: kCatSize - 36,
          child: _sprite(_kCatFlat, 12, {
            'w': ds.icon1,
            'e': ds.catEye,
          }, key: const ValueKey('cat-flat')),
        ),
      );
    }
    final starsOn = t >= 1550 && t < 2350;
    if (starsOn) {
      final fade = t < 2200
          ? 1.0
          : 1 - Curves.easeIn.transform((t - 2200) / 150);
      for (var i = 0; i < 3; i++) {
        final a = 2 * math.pi * ((t - 1550) / 450 + i / 3) + 0.5;
        props.add(
          Positioned(
            left: 50 + 44 * math.cos(a),
            top: -26 + 16 * math.sin(a),
            child: Opacity(
              opacity: fade.clamp(0, 1),
              child: _sprite(_kStar, 4, {'w': ds.text1}),
            ),
          ),
        );
      }
    }
    if (t < 1750) {
      final x = _track(t, const [
        (0, 255, Curves.linear),
        (550, -20, Curves.easeOut),
        (725, -42, Curves.easeInOut),
        (900, 2, Curves.easeInOut),
        (1075, -42, Curves.easeInOut),
        (1250, -20, Curves.easeInOut),
        (1750, -295, Curves.easeIn),
      ]);
      final opacity = math.min(math.min(t / 100, (1750 - t) / 100), 1.0);
      props.add(
        Positioned(
          left: x,
          top: kCatSize - 72,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: _sprite(_kIron, 8, {
              'a': ds.accent,
              'w': ds.text1,
            }, key: const ValueKey('cat-iron')),
          ),
        ),
      );
    }
    return props;
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final violet = widget.strongGlow;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glowSize = violet ? kCatGlowStrong : kCatGlow;
    final glowColor = violet ? ds.accentAlpha : ds.highlightMuted;
    final reach = glowSize + kCatGlowBlur * 2;
    Widget cat = CustomPaint(
      size: const Size.square(kCatSize),
      painter: CatPainter(frame: _frame, body: ds.icon1, eyes: ds.catEye),
    );
    if (_flat) cat = const SizedBox.square(dimension: kCatSize);
    cat = Transform.rotate(
      angle: _angle * math.pi / 180,
      child: Transform.scale(scale: _scale, child: cat),
    );
    final drop = _drop;
    if (drop != 0) {
      cat = ClipRect(
        child: Transform.translate(offset: Offset(0, drop), child: cat),
      );
    }
    return ExcludeSemantics(
      child: Opacity(
        opacity: widget.dimmed ? kDisabledOpacity : 1,
        child: SizedBox(
          width: kCatStageWidth,
          height: kCatStageHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (violet || dark)
                Positioned(
                  key: ValueKey(violet ? 'cat-glow-violet' : 'cat-glow-muted'),
                  left: (kCatStageWidth - reach) / 2,
                  top: (kCatStageHeight - reach) / 2,
                  width: reach,
                  height: reach,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: violet ? 1 : kCatGlowMutedOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glowColor,
                              glowColor,
                              glowColor.withValues(alpha: 0),
                            ],
                            stops: [0, glowSize / reach * 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              MouseRegion(
                cursor:
                    widget.mood == CatMood.awake ||
                        widget.mood == CatMood.asleep
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _tap,
                  child: SizedBox.square(
                    dimension: kCatSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        cat,
                        ..._props(ds),
                        if (widget.mood == CatMood.asleep)
                          Positioned(
                            left: 105.6,
                            top: -26.4 + _hop,
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
            ],
          ),
        ),
      ),
    );
  }
}
