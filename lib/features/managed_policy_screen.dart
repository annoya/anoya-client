import 'package:flutter/material.dart';

import '../core/geo_store.dart';
import '../core/norm_config.dart';
import '../core/rule_set.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import 'policy_origin.dart';
import 'routing_widgets.dart';

class ManagedPolicyScreen extends StatefulWidget {
  const ManagedPolicyScreen(
    this.policy, {
    this.origin,
    this.listsAvailable,
    super.key,
  });

  final Routing policy;

  final PolicyOrigin? origin;

  final Set<String>? listsAvailable;

  @override
  State<ManagedPolicyScreen> createState() => _ManagedPolicyScreenState();
}

class _ManagedPolicyScreenState extends State<ManagedPolicyScreen> {
  bool? _geoReady;
  bool _geoBusy = false;

  @override
  void initState() {
    super.initState();
    GeoStore.status().then((geo) {
      if (mounted) setState(() => _geoReady = geo.downloaded);
    });
  }

  Future<void> _downloadGeo() async {
    setState(() => _geoBusy = true);
    final ready = await downloadGeoDatabases(context);
    if (!mounted) return;
    setState(() {
      _geoBusy = false;
      if (ready != null) _geoReady = ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final geoReady = _geoReady;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleSetSplitTunneling)),
      body: geoReady == null
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _originBanner(context),
                  if (!geoReady && policy.rules.any((r) => r.needsGeoData))
                    GeoDownloadBanner(
                      title: l10n.ruleSetGeoNotDownloaded,
                      subtitle: l10n.ruleSetGeoNotDownloadedDetail,
                      busy: _geoBusy,
                      onDownload: _downloadGeo,
                    ),
                  RoutingModeCard(mode: RoutingMode.parse(policy.mode)),
                  SectionHeader(l10n.ruleSetRulesHeader),
                  if (policy.rules.isEmpty)
                    emptyRulesNote(context, RoutingMode.parse(policy.mode))
                  else
                    for (final rule in policy.rules)
                      RuleTile(
                        rule: rule,
                        geoReady: geoReady,
                        listNames: widget.listsAvailable ?? const {},
                        listsOff:
                            widget.listsAvailable == null &&
                            policy.lists.isNotEmpty,
                      ),
                ],
              ),
            ),
    );
  }

  Widget _originBanner(BuildContext context) {
    final origin = widget.origin ?? PolicyOrigin.organization;
    return Card(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(origin.icon),
        title: Text(origin.title),
        subtitle: Text(origin.detail),
        isThreeLine: origin.detail.length > 60,
      ),
    );
  }
}
