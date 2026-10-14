import 'package:flutter/material.dart';

import '../core/ds.dart';
import '../core/geo_store.dart';
import '../core/norm_config.dart';
import '../core/rule_set.dart';
import '../core/theme.dart';
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
    final mode = RoutingMode.parse(policy.mode);
    if (geoReady == null) {
      return DsPage(
        title: l10n.ruleSetSplitTunneling,
        body: const Center(child: DsSpinner()),
      );
    }
    final origin = widget.origin ?? PolicyOrigin.organization;
    return DsPage(
      title: l10n.ruleSetSplitTunneling,
      children: [
        DsCard(
          color: context.ds.accentSubtle,
          children: [
            DsRow(
              glyph: origin.glyph,
              title: origin.title,
              subtitle: origin.detail,
              subtitleMaxLines: 3,
            ),
          ],
        ),
        if (!geoReady && policy.rules.any((r) => r.needsGeoData))
          GeoDownloadBanner(
            title: l10n.ruleSetGeoNotDownloaded,
            subtitle: l10n.ruleSetGeoNotDownloadedDetail,
            busy: _geoBusy,
            onDownload: _downloadGeo,
          ),
        RoutingModeCard(mode: mode),
        DsGroup(
          caption: l10n.ruleSetRulesHeader,
          child: policy.rules.isEmpty
              ? emptyRulesNote(context, mode)
              : DsCard(
                  children: [
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
      ],
    );
  }
}
