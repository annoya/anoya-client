import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/routing_prefs.dart';
import '../core/ui.dart';
import '../state/providers.dart';

/// GeoIP & GeoSite database management: source URLs (editable), current
/// size/age, manual update and the weekly auto-update switch. geoip/geosite
/// rules stay inactive until both files are downloaded.
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
    // The download stamps geoUpdatedAt into the file behind the provider's
    // back, so the copy the screen shows is refreshed alongside the sizes.
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
      // Nothing is broken without fresh databases — the old ones keep working.
      if (mounted) {
        showToast(context, describeError(e, subject: 'the database host').line);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUrl({required bool geoip}) async {
    // "Reset to default" lives in the content, not in actions: three buttons
    // in the action bar wrap onto two lines on a phone.
    final url = await promptText(
      context,
      title: geoip ? 'GeoIP source' : 'GeoSite source',
      label: 'Download URL',
      confirmLabel: 'Save',
      initial: geoip ? _prefs.geoipUrl : _prefs.geositeUrl,
      longValue: true, // a 90-character download URL
      autocorrect: false,
      resetLabel: 'Reset to default',
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

  /// One database row: name + size on the title line, the source URL on one
  /// truncated line below. The full URL is only shown in the edit dialog —
  /// wrapping a 90-char URL across three lines made the row dwarf everything
  /// else on the screen.
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

  /// host + filename, e.g. "github.com/…/geoip.metadb".
  String _shortUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return url;
    final file = u.pathSegments.isEmpty ? '' : u.pathSegments.last;
    return file.isEmpty ? u.host : '${u.host}/…/$file';
  }

  String _bytes(int n) => n <= 0 ? 'not downloaded' : formatBytes(n);

  String _updatedAt(RoutingPrefs prefs) {
    final at = prefs.geoUpdatedAt;
    if (at == null || !_status.downloaded) return 'never';
    final d = DateTime.now().difference(at);
    if (d.inDays > 0) return '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago';
    if (d.inHours > 0) {
      return '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago';
    }
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(routingPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GeoIP & GeoSite')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                children: [
                  const SectionHeader('DATABASES'),
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
                  const SectionHeader('UPDATES'),
                  Card(
                    margin: kCardMargin,
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Last updated'),
                          subtitle: Text(_updatedAt(prefs)),
                        ),
                        SwitchListTile(
                          title: const Text('Auto-update'),
                          subtitle: const Text(
                            'Weekly, when already downloaded',
                          ),
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
                        _status.downloaded ? 'Update now' : 'Download (~25 MB)',
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
