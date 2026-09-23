import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Who authored a policy shown read-only, in the words its banner uses.
class PolicyOrigin {
  const PolicyOrigin({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// A self-hosted deployment: the server both sets the policy and enforces it,
  /// so there is nothing here for the user to decide.
  static PolicyOrigin get organization => PolicyOrigin(
    icon: Icons.business_outlined,
    title: L10n.current.configManagedByOrganization,
    detail: L10n.current.configOrganizationPolicyDetail,
  );

  /// A subscription's panel: it sent rules, and the next refresh may send
  /// different ones, but it cannot make this device obey them (ADR-005).
  static PolicyOrigin provider(String name, {int skipped = 0}) => PolicyOrigin(
    icon: Icons.cloud_outlined,
    title: L10n.current.configSentBy(name),
    detail: skipped == 0
        ? L10n.current.configProviderPolicyDetail
        : L10n.current.configProviderPolicyDetailSkipped(skipped),
  );
}
