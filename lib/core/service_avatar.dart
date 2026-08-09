import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'service_catalog.dart';

/// 26pt round avatar for a geosite category: the brand's monochrome glyph
/// (Simple Icons, bundled — icons are never fetched from the network: a VPN
/// app must not broadcast which services the user is about to route) tinted to
/// the theme, or the first letter for categories without one.
class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar(this.label, {super.key, this.category});

  final String label;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = category == null ? null : catalogServiceFor(category!);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: service != null && service.glyph
          ? SvgPicture.asset(
              service.glyphAsset,
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(cs.onPrimaryContainer, BlendMode.srcIn),
            )
          : Text(
              label.isEmpty ? '?' : label[0].toUpperCase(),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
            ),
    );
  }
}
