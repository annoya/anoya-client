import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';
import '../core/ui.dart';

/// What this build is, and where the documents about it live.
///
/// Its own screen rather than a section in Settings: settings are things the
/// user changes, and nothing here changes anything. The one action is copying
/// the version, which is what support asks for first.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: PageBody(
        child: ListView(children: [
          // Not a card: a card would promise that tapping it does something.
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 28, kGutter, 20),
            child: Column(children: [
              Icon(Icons.shield_outlined, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              Text(kAppName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Version $appVersionLabel',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          Card(
            margin: kCardMargin,
            child: ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Engine'),
              subtitle: Text(engineVersionLabel),
              // The row is shortened for reading; a bug report wants the whole
              // pin, so that is what copying gives.
              trailing: IconButton(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: '$kAppName $appVersionLabel · mihomo $kEnginePin'));
                  if (context.mounted) showToast(context, 'Version copied');
                },
              ),
            ),
          ),
          const Card(
            margin: kCardMargin,
            child: Column(children: [
              _LegalRow(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                url: kTermsUrl,
              ),
              Divider(height: 1, indent: 16, endIndent: 16),
              _LegalRow(
                icon: Icons.lock_outline,
                title: 'Privacy Policy',
                url: kPrivacyUrl,
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

/// A document that may not exist yet.
///
/// Dimmed and inert while its address is empty, and saying so: a row that looks
/// alive and leads nowhere reads as broken, and a hidden one does not say the
/// document is coming. It lights up on its own once the address is filled in.
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
        subtitle: published ? null : const Text('Not published yet'),
        trailing: published ? const Icon(Icons.open_in_new, size: 18) : null,
        onTap: !published
            ? null
            : () async {
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  if (context.mounted) showToast(context, 'Couldn’t open that page.');
                }
              },
      ),
    );
  }
}
