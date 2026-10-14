import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_logo.dart';
import '../core/app_version.dart';
import '../core/ds.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copyVersion(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: '$kAppName $appVersionLabel · mihomo $kEnginePin'),
    );
    if (context.mounted) showToast(context, context.l10n.aboutVersionCopied);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    return DsPage(
      title: l10n.aboutTitle,
      children: [
        Column(
          children: [
            AppLogo(size: 56, color: ds.accent),
            const SizedBox(height: 12),
            Text(kAppName, style: DsType.h2.copyWith(color: ds.text1)),
            const SizedBox(height: 4),
            Text(
              l10n.aboutVersion(appVersionLabel),
              style: DsType.small.copyWith(color: ds.text3),
            ),
          ],
        ),
        DsCard(
          children: [
            DsRow(
              glyph: Glyph.zap,
              title: l10n.aboutEngine,
              subtitle: engineVersionLabel,
              onTap: () => _copyVersion(context),
              trailing: [
                DsAction(
                  glyph: Glyph.copy,
                  tooltip: l10n.commonCopy,
                  onPressed: () => _copyVersion(context),
                ),
              ],
            ),
          ],
        ),
        DsCard(
          children: [
            _LegalRow(
              glyph: Glyph.fileText,
              title: l10n.aboutTermsOfService,
              url: kTermsUrl,
            ),
            _LegalRow(
              glyph: Glyph.lock,
              title: l10n.aboutPrivacyPolicy,
              url: kPrivacyUrl,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.glyph,
    required this.title,
    required this.url,
  });

  final Glyph glyph;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final published = url.isNotEmpty;
    return DsRow(
      glyph: glyph,
      title: title,
      subtitle: published ? null : context.l10n.aboutNotPublishedYet,
      enabled: published,
      trailing: [if (published) const DsAction(glyph: Glyph.externalLink)],
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            showToast(context, context.l10n.uiCouldNotOpenPage);
          }
        }
      },
    );
  }
}
