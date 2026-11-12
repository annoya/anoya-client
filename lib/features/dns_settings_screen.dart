import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dns_plan.dart';
import '../core/ds.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import 'corp_domains_screen.dart';

const _custom = '__custom__';

class DnsSettingsScreen extends ConsumerWidget {
  const DnsSettingsScreen({super.key});

  Future<void> _pickDefaultDns(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(routingPrefsProvider).defaultDns;
    final picked = await pickOption<String>(
      context,
      title: l10n.settingsDefaultDns,
      radio: true,
      selected: kDnsPresets.any((p) => p.address == current)
          ? current
          : _custom,
      options: [
        for (final p in kDnsPresets)
          Option(
            p.address,
            p.name,
            subtitle: p.note.isEmpty ? p.address : '${p.address} · ${p.note}',
          ),
        Option(
          _custom,
          l10n.settingsDnsCustom,
          subtitle: l10n.settingsDnsCustomSubtitle,
        ),
      ],
    );
    if (picked == null || !context.mounted) return;

    var value = picked;
    if (picked == _custom) {
      final typed = await _typeAddress(
        context,
        title: l10n.settingsDefaultDns,
        initial: current,
        hint: 'https://1.1.1.1/dns-query',
        resetLabel: l10n.settingsDnsUseCloudflare,
        resetValue: kFallbackNameserver,
      );
      if (typed == null) return;
      value = typed;
    }

    await ref
        .read(routingPrefsProvider.notifier)
        .update((p) => p.copyWith(defaultDns: value));
  }

  Future<void> _pickLocalDns(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(routingPrefsProvider).localDns;
    final presets = kDnsPresets.where((p) => p.note.isEmpty);
    final picked = await pickOption<String>(
      context,
      title: l10n.dnsSettingsLocal,
      radio: true,
      selected: current.isEmpty || presets.any((p) => p.address == current)
          ? current
          : _custom,
      options: [
        Option('', l10n.commonOff, subtitle: l10n.dnsSettingsLocalOffSubtitle),
        for (final p in presets) Option(p.address, p.name, subtitle: p.address),
        Option(
          _custom,
          l10n.settingsDnsCustom,
          subtitle: l10n.dnsSettingsLocalCustomSubtitle,
        ),
      ],
    );
    if (picked == null || !context.mounted) return;

    var value = picked;
    if (picked == _custom) {
      final typed = await _typeAddress(
        context,
        title: l10n.dnsSettingsLocal,
        initial: current,
        hint: '77.88.8.8',
      );
      if (typed == null) return;
      value = typed;
    }

    await ref
        .read(routingPrefsProvider.notifier)
        .update((p) => p.copyWith(localDns: value));
  }

  Future<String?> _typeAddress(
    BuildContext context, {
    required String title,
    required String initial,
    required String hint,
    String? resetLabel,
    String? resetValue,
  }) async {
    final l10n = context.l10n;
    final typed = await promptText(
      context,
      title: title,
      label: l10n.settingsDnsResolverLabel,
      confirmLabel: l10n.commonSave,
      initial: initial,
      hint: hint,
      autocorrect: false,
      resetLabel: resetLabel,
      resetValue: resetValue,
      errorOf: (value) =>
          value.trim().isEmpty ? null : dnsDefaultError(value.trim()),
    );
    if (typed == null || !context.mounted) return null;
    final error = dnsDefaultError(typed.trim());
    if (error != null) {
      showToast(context, error);
      return null;
    }
    return typed.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(routingPrefsProvider);
    return DsPage(
      title: l10n.settingsDns,
      children: [
        DsGroup(
          caption: l10n.dnsSettingsThroughVpn,
          note: l10n.dnsSettingsDefaultNote,
          children: [
            DsRow(
              glyph: Glyph.globe,
              title: l10n.settingsDefaultDns,
              subtitle: dnsPresetName(prefs.defaultDns),
              subtitleMaxLines: 1,
              trailing: const [DsChevron(down: true)],
              onTap: () => _pickDefaultDns(context, ref),
            ),
          ],
        ),
        DsGroup(
          caption: l10n.dnsSettingsOutsideVpn,
          note: l10n.dnsSettingsLocalNote,
          children: [
            DsRow(
              glyph: Glyph.network,
              title: l10n.dnsSettingsLocal,
              subtitle: prefs.localDns.isEmpty
                  ? l10n.commonOff
                  : dnsPresetName(prefs.localDns),
              subtitleMaxLines: 1,
              trailing: const [DsChevron(down: true)],
              onTap: () => _pickLocalDns(context, ref),
            ),
          ],
        ),
        DsGroup(
          caption: l10n.dnsSettingsCompany,
          note: l10n.dnsSettingsCorpNote,
          children: [
            DsRow(
              glyph: Glyph.building2,
              title: l10n.settingsCorpDomains,
              subtitle: prefs.corpDomains.isEmpty
                  ? l10n.commonOff
                  : prefs.corpDomains.expand((c) => c.domains).join(', '),
              subtitleMaxLines: 1,
              trailing: const [DsChevron()],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CorpDomainsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
