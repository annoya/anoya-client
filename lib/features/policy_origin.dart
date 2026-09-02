import 'package:flutter/material.dart';

/// Who authored a policy shown read-only, in the words its banner uses.
class PolicyOrigin {
  const PolicyOrigin({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  /// A self-hosted deployment: the server both sets the policy and enforces it,
  /// so there is nothing here for the user to decide.
  static const organization = PolicyOrigin(
    icon: Icons.business_outlined,
    title: 'Managed by your organization',
    detail: 'These rules are set on the server and cannot be changed here.',
  );

  /// A subscription's panel: it sent rules, and the next refresh may send
  /// different ones, but it cannot make this device obey them (ADR-005).
  static PolicyOrigin provider(String name, {int skipped = 0}) => PolicyOrigin(
        icon: Icons.cloud_outlined,
        title: 'Sent by $name',
        detail: skipped == 0
            ? 'Read-only. Refreshing the subscription replaces them.'
            : 'Read-only. Refreshing the subscription replaces them. '
                '$skipped more rule${skipped > 1 ? 's' : ''} could not be '
                'translated for this app and ${skipped > 1 ? 'are' : 'is'} not applied.',
      );
}
