import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'ds.dart';
import 'service_catalog.dart';
import 'theme.dart';

class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar(this.label, {super.key, this.category});

  final String label;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final service = category == null ? null : catalogServiceFor(category!);
    if (service == null || !service.glyph) {
      return const GlyphIcon(Glyph.globe, size: kRowIcon);
    }
    return SvgPicture.asset(
      service.glyphAsset,
      width: kRowIcon,
      height: kRowIcon,
      colorFilter: ColorFilter.mode(context.ds.icon1, BlendMode.srcIn),
    );
  }
}
