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
    final color = context.ds.icon2;
    if (service == null) return GlyphIcon(Glyph.globe, color: color);
    if (!service.glyph) {
      return SizedBox.square(
        dimension: kRowIcon,
        child: Center(
          child: Text(
            label.isEmpty ? '?' : label[0].toUpperCase(),
            style: DsType.h4.copyWith(color: color),
          ),
        ),
      );
    }
    return SvgPicture.asset(
      service.glyphAsset,
      width: kRowIcon,
      height: kRowIcon,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
