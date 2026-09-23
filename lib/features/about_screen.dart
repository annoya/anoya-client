import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 28, kGutter, 20),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    kAppName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.aboutVersion(appVersionLabel),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: Text(l10n.aboutEngine),
                subtitle: Text(engineVersionLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  tooltip: l10n.commonCopy,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: '$kAppName $appVersionLabel · mihomo $kEnginePin',
                      ),
                    );
                    if (context.mounted) {
                      showToast(context, l10n.aboutVersionCopied);
                    }
                  },
                ),
              ),
            ),
            Card(
              margin: kCardMargin,
              child: Column(
                children: [
                  _LegalRow(
                    icon: Icons.description_outlined,
                    title: l10n.aboutTermsOfService,
                    url: kTermsUrl,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _LegalRow(
                    icon: Icons.lock_outline,
                    title: l10n.aboutPrivacyPolicy,
                    url: kPrivacyUrl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({required this.icon, required this.title, required this.url});

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final published = url.isNotEmpty;
    return Opacity(
      opacity: published ? 1 : 0.38,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: published ? null : Text(context.l10n.aboutNotPublishedYet),
        trailing: published ? const Icon(Icons.open_in_new, size: 18) : null,
        onTap: !published
            ? null
            : () async {
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                  if (context.mounted) {
                    showToast(context, context.l10n.uiCouldNotOpenPage);
                  }
                }
              },
      ),
    );
  }
}
