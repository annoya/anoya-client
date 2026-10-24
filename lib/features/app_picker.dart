import 'package:flutter/material.dart';

import '../core/android_apps.dart';
import '../core/ds.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.app, {super.key});

  final AndroidApp? app;

  @override
  Widget build(BuildContext context) {
    final icon = app?.icon;
    return SizedBox.square(
      dimension: kRowIcon,
      child: icon == null
          ? const GlyphIcon(Glyph.smartphone)
          : ClipRRect(
              borderRadius: BorderRadius.circular(kAppIconRadius),
              child: Image.memory(
                icon,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
    );
  }
}

Future<Set<String>?> pickApps(
  BuildContext context, {
  Set<String> selected = const {},
}) async {
  final apps = await AndroidApps.installed();
  if (!context.mounted) return null;
  final chosen = [
    for (final a in apps)
      if (selected.contains(a.package)) a,
  ];
  final rest = [
    for (final a in apps)
      if (!selected.contains(a.package)) a,
  ];
  return pickOptions<String>(
    context,
    title: context.l10n.appPickerTitle,
    selected: selected,
    options: [
      for (final a in [...chosen, ...rest])
        Option(a.package, a.label, subtitle: a.package, leading: AppIcon(a)),
    ],
  );
}

Map<String, AndroidApp> appsByPackage(List<AndroidApp> apps) => {
  for (final a in apps) a.package: a,
};
