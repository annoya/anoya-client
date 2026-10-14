import '../core/ds.dart';
import '../l10n/l10n.dart';

class PolicyOrigin {
  const PolicyOrigin({
    required this.glyph,
    required this.title,
    required this.detail,
  });

  final Glyph glyph;
  final String title;
  final String detail;

  static PolicyOrigin get organization => PolicyOrigin(
    glyph: Glyph.building2,
    title: L10n.current.configManagedByOrganization,
    detail: L10n.current.configOrganizationPolicyDetail,
  );

  static PolicyOrigin provider(String name, {int skipped = 0}) => PolicyOrigin(
    glyph: Glyph.folder,
    title: L10n.current.configSentBy(name),
    detail: skipped == 0
        ? L10n.current.configProviderPolicyDetail
        : L10n.current.configProviderPolicyDetailSkipped(skipped),
  );
}
