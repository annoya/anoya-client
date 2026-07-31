import 'package:flutter/material.dart';

import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/routing_prefs.dart';
import '../core/ui.dart';

/// GeoIP & GeoSite database management: source URLs (editable), current
/// size/age, manual update and the weekly auto-update switch. geoip/geosite
/// rules stay inactive until both files are downloaded.
class GeoScreen extends StatefulWidget {
  const GeoScreen({super.key});

  @override
  State<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends State<GeoScreen> {
  RoutingPrefs _prefs = const RoutingPrefs();
  GeoStatus _status = const GeoStatus();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await RoutingPrefsStore.load();
    final status = await GeoStore.status();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _status = status;
      _loading = false;
    });
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GeoStore.download();
      await _load();
    } catch (e) {
      Log.e('geo update failed', '$e');
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUrl({required bool geoip}) async {
    final controller =
        TextEditingController(text: geoip ? _prefs.geoipUrl : _prefs.geositeUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(geoip ? 'GeoIP source' : 'GeoSite source'),
        // "Reset to default" lives in the content, not in actions: three
        // buttons in the action bar wrap onto two lines on a phone.
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            maxLines: 4,
            minLines: 1,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(labelText: 'Download URL'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset to default'),
              onPressed: () => controller.text =
                  geoip ? RoutingPrefs.defaultGeoipUrl : RoutingPrefs.defaultGeositeUrl,
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    final updated =
        geoip ? _prefs.copyWith(geoipUrl: url) : _prefs.copyWith(geositeUrl: url);
    await RoutingPrefsStore.save(updated);
    setState(() => _prefs = updated);
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
        title: Row(children: [
          Expanded(child: Text(name)),
          Text(_bytes(bytes), style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ]),
        subtitle: Text(_shortUrl(url), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  String _bytes(int n) {
    if (n <= 0) return 'not downloaded';
    const mb = 1024 * 1024;
    return n >= mb ? '${(n / mb).toStringAsFixed(1)} MB' : '${(n / 1024).toStringAsFixed(0)} KB';
  }

  String _updatedAt() {
    final at = _prefs.geoUpdatedAt;
    if (at == null || !_status.downloaded) return 'never';
    final d = DateTime.now().difference(at);
    if (d.inDays > 0) return '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago';
    if (d.inHours > 0) return '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    url: _prefs.geoipUrl,
                    bytes: _status.geoipBytes,
                    onEdit: () => _editUrl(geoip: true),
                  ),
                  _dbCard(
                    name: 'GeoSite',
                    url: _prefs.geositeUrl,
                    bytes: _status.geositeBytes,
                    onEdit: () => _editUrl(geoip: false),
                  ),
                  const SectionHeader('UPDATES'),
                  Card(
                    margin: kCardMargin,
                    child: Column(children: [
                      ListTile(
                        title: const Text('Last updated'),
                        subtitle: Text(_updatedAt()),
                      ),
                      SwitchListTile(
                        title: const Text('Auto-update'),
                        subtitle: const Text('Weekly, when already downloaded'),
                        value: _prefs.geoAutoUpdate,
                        onChanged: (v) async {
                          final updated = _prefs.copyWith(geoAutoUpdate: v);
                          await RoutingPrefsStore.save(updated);
                          setState(() => _prefs = updated);
                        },
                      ),
                    ]),
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
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_status.downloaded ? 'Update now' : 'Download (~25 MB)'),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(kGutter),
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
