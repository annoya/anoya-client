import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class PolicyOrigin {
  const PolicyOrigin({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  static PolicyOrigin get organization => PolicyOrigin(
    icon: Icons.business_outlined,
    title: L10n.current.configManagedByOrganization,
    detail: L10n.current.configOrganizationPolicyDetail,
  );

  static PolicyOrigin provider(String name, {int skipped = 0}) => PolicyOrigin(
    icon: Icons.cloud_outlined,
    title: L10n.current.configSentBy(name),
    detail: skipped == 0
        ? L10n.current.configProviderPolicyDetail
        : L10n.current.configProviderPolicyDetailSkipped(skipped),
  );
}
