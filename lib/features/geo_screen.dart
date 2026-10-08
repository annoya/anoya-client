import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/routing_prefs.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';

class GeoScreen extends ConsumerStatefulWidget {
  const GeoScreen({super.key});

  @override
  ConsumerState<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends ConsumerState<GeoScreen> {
  GeoStatus _status = const GeoStatus();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ref.read(routingPrefsProvider.notifier).reload();
    final status = await GeoStore.status();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  RoutingPrefs get _prefs => ref.read(routingPrefsProvider);

  Future<void> _update() async {
    setState(() {
      _busy = true;
    });
    try {
      await GeoStore.download();
      await _load();
    } catch (e) {
      Log.e('geo update failed', '$e');
      if (mounted) {
        showToast(
          context,
          describeError(e, subject: context.l10n.geoDatabaseHostSubject).line,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUrl({required bool geoip}) async {
    final l10n = context.l10n;
    final url = await promptText(
      context,
      title: geoip ? l10n.geoGeoipSource : l10n.geoGeositeSource,
      label: l10n.geoDownloadUrlLabel,
      confirmLabel: l10n.commonSave,
      initial: geoip ? _prefs.geoipUrl : _prefs.geositeUrl,
      longValue: true,
      autocorrect: false,
      resetLabel: l10n.geoResetToDefault,
      resetValue: geoip
          ? RoutingPrefs.defaultGeoipUrl
          : RoutingPrefs.defaultGeositeUrl,
    );
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await ref
        .read(routingPrefsProvider.notifier)
        .update(
          (p) => geoip
              ? p.copyWith(geoipUrl: trimmed)
              : p.copyWith(geositeUrl: trimmed),
        );
  }

  Widget _dbCard({
    required String name,
    required String url,
    required int bytes,
    required VoidCallback onEdit,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(name)),
            Text(
              _bytes(bytes),
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        subtitle: Text(
          _shortUrl(url),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: _busy ? null : onEdit,
      ),
    );
  }

  String _shortUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return url;
    final file = u.pathSegments.isEmpty ? '' : u.pathSegments.last;
    return file.isEmpty ? u.host : '${u.host}/…/$file';
  }

  String _bytes(int n) =>
      n <= 0 ? context.l10n.geoNotDownloaded : formatBytes(n);

  String _updatedAt(RoutingPrefs prefs) {
    final l10n = context.l10n;
    final at = prefs.geoUpdatedAt;
    if (at == null || !_status.downloaded) return l10n.geoNever;
    final d = DateTime.now().difference(at);
    if (d.inDays > 0) return l10n.commonDaysAgo(d.inDays);
    if (d.inHours > 0) return l10n.commonHoursAgo(d.inHours);
    return l10n.commonJustNow;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(routingPrefsProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.geoTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                children: [
                  SectionHeader(l10n.geoSectionDatabases),
                  _dbCard(
                    name: 'GeoIP',
                    url: prefs.geoipUrl,
                    bytes: _status.geoipBytes,
                    onEdit: () => _editUrl(geoip: true),
                  ),
                  _dbCard(
                    name: 'GeoSite',
                    url: prefs.geositeUrl,
                    bytes: _status.geositeBytes,
                    onEdit: () => _editUrl(geoip: false),
                  ),
                  SectionHeader(l10n.geoSectionUpdates),
                  Card(
                    margin: kCardMargin,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(l10n.geoLastUpdated),
                          subtitle: Text(_updatedAt(prefs)),
                        ),
                        SwitchListTile(
                          title: Text(l10n.geoAutoUpdate),
                          subtitle: Text(l10n.geoAutoUpdateSubtitle),
                          value: prefs.geoAutoUpdate,
                          onChanged: (v) => ref
                              .read(routingPrefsProvider.notifier)
                              .update((p) => p.copyWith(geoAutoUpdate: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kGutter),
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _update,
                      icon: _busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _status.downloaded
                            ? (_busy ? l10n.geoUpdating : l10n.geoUpdateNow)
                            : (_busy ? l10n.geoDownloading : l10n.geoDownload),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
