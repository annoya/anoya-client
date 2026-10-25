import '../l10n/l10n.dart';

Map<String, String> tunnelNotice({
  required String configuration,
  required String server,
}) {
  final l10n = L10n.current;
  return {
    'configuration': configuration,
    'channel_problems': l10n.noticeChannelProblems,
    'connected': l10n.noticeConnected(server),
    'silent_title': l10n.noticeSilentTitle,
    'silent_body': l10n.noticeSilentBody(server),
    'connected_silent': l10n.noticeConnectedSilent,
    'connected_silent_detail': l10n.noticeConnectedSilentDetail(server),
    'start_failed_title': l10n.noticeStartFailedTitle,
    'start_failed_body': l10n.noticeStartFailedBody,
  };
}
