import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

enum Glyph {
  activity('activity'),
  alertTriangle('alert-triangle'),
  arrowLeft('arrow-left'),
  bot('bot'),
  briefcase('briefcase'),
  building2('building-2'),
  calendar('calendar'),
  cameraOff('camera-off'),
  check('check'),
  checkSquare('check-square'),
  chevronDown('chevron-down'),
  chevronLeft('chevron-left'),
  chevronRight('chevron-right'),
  chevronUp('chevron-up'),
  circleCheck('circle-check'),
  clipboard('clipboard'),
  clock('clock'),
  cloud('cloud'),
  cloudOff('cloud-off'),
  copy('copy'),
  cpu('cpu'),
  database('database'),
  download('download'),
  ellipsisVertical('ellipsis-vertical'),
  externalLink('external-link'),
  eye('eye'),
  eyeOff('eye-off'),
  file('file'),
  fileText('file-text'),
  flashlight('flashlight'),
  flashlightOff('flashlight-off'),
  folder('folder'),
  github('github'),
  globe('globe'),
  gripVertical('grip-vertical'),
  history('history'),
  image('image'),
  info('info'),
  languages('languages'),
  layers('layers'),
  link('link'),
  list('list'),
  loader2('loader-2'),
  lock('lock'),
  minus('minus'),
  monitor('monitor'),
  moon('moon'),
  music('music'),
  network('network'),
  pencil('pencil'),
  plus('plus'),
  plusCircle('plus-circle'),
  qrCode('qr-code'),
  refreshCw('refresh-cw'),
  rotateCcw('rotate-ccw'),
  route('route'),
  scale('scale'),
  scan('scan'),
  search('search'),
  send('send'),
  server('server'),
  settings('settings'),
  share('share'),
  share2('share-2'),
  shield('shield'),
  smartphone('smartphone'),
  split('split'),
  square('square'),
  star('star'),
  starOff('star-off'),
  sunMoon('sun-moon'),
  timer('timer'),
  trash('trash'),
  trash2('trash-2'),
  tv('tv'),
  upload('upload'),
  user('user'),
  users('users'),
  wifi('wifi'),
  x('x'),
  xCircle('x-circle'),
  youtube('youtube'),
  zap('zap');

  const Glyph(this.fileName);
  final String fileName;

  String get asset => 'assets/icons/$fileName.svg';
}

class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size, this.color, this.label});

  final Glyph glyph;
  final double? size;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? kRowIcon;
    final tint = color ?? theme.color ?? context.ds.icon1;
    return SvgPicture.asset(
      glyph.asset,
      width: side,
      height: side,
      semanticsLabel: label,
      excludeFromSemantics: label == null,
      colorFilter: ColorFilter.mode(
        tint.withValues(alpha: tint.a * (theme.opacity ?? 1)),
        BlendMode.srcIn,
      ),
    );
  }
}
