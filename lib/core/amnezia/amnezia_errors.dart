import '../../l10n/l10n.dart';
import '../app_error.dart';
import 'agw_ffi.dart';

AppError describeAmneziaError(AgwResponse res) {
  final (title, ours) = res.code == AgwStatus.ok
      ? _refusal(res)
      : _transport(res.code);
  final theirs = res.message;
  return AppError(title, detail: theirs.isNotEmpty ? theirs : ours);
}

AppError get kAmneziaEmptyAnswer => AppError(
  L10n.current.amneziaErrorEmptyAnswerTitle,
  detail: L10n.current.amneziaErrorEmptyAnswerDetail,
);

(String, String) _transport(int code) {
  final l10n = L10n.current;
  return switch (code) {
    AgwStatus.cancelled => (
      l10n.amneziaErrorCancelledTitle,
      l10n.amneziaErrorCancelledDetail,
    ),
    AgwStatus.network => (
      l10n.amneziaErrorNetworkTitle,
      l10n.amneziaErrorNetworkDetail,
    ),
    AgwStatus.timeout => (
      l10n.amneziaErrorTimeoutTitle,
      l10n.amneziaErrorTimeoutDetail,
    ),
    AgwStatus.ssl => (l10n.amneziaErrorSslTitle, l10n.amneziaErrorSslDetail),
    AgwStatus.config => (
      l10n.amneziaErrorConfigTitle,
      l10n.amneziaErrorConfigDetail,
    ),
    AgwStatus.decrypt => (
      l10n.amneziaErrorDecryptTitle,
      l10n.amneziaErrorDecryptDetail,
    ),
    AgwStatus.invalidArgument => (
      l10n.amneziaErrorInvalidArgumentTitle,
      l10n.amneziaErrorInvalidArgumentDetail,
    ),
    _ => (
      l10n.amneziaErrorRefusedTitle,
      l10n.amneziaErrorRefusedCodeDetail(code),
    ),
  };
}

(String, String) _refusal(AgwResponse res) {
  final l10n = L10n.current;
  final message = res.message.toLowerCase();
  bool says(String needle) => message.contains(needle);
  switch (res.httpStatus) {
    case 429:
      return (
        l10n.amneziaErrorTooManyRequestsTitle,
        l10n.amneziaErrorTooManyRequestsDetail,
      );
    case 409:
      if (says('trial subscription already used')) {
        return (
          l10n.amneziaErrorTrialUsedTitle,
          l10n.amneziaErrorTrialUsedDetail,
        );
      }
      return (l10n.errorDeviceLimitTitle, l10n.amneziaErrorDeviceLimitDetail);
    case 404:
      return (l10n.amneziaErrorNotFoundTitle, l10n.amneziaErrorNotFoundDetail);
    case 408:
      return (l10n.amneziaErrorTimeoutTitle, l10n.amneziaErrorTimeoutDetail);
    case 501:
      return (
        l10n.amneziaErrorNewerClientTitle,
        l10n.amneziaErrorNewerClientDetail,
      );
    case 422:
      if (says('failed to retrieve subscription information')) {
        return (l10n.accountExpiredTitle, l10n.configSubscriptionExpiredDetail);
      }
    case 402:
      final pass = l10n.amneziaErrorCaptchaPass;
      if (says('refresh_captcha')) {
        return (l10n.amneziaErrorCaptchaExpiredTitle, pass);
      }
      if (says('invalid_captcha')) {
        return (l10n.amneziaErrorCaptchaRejectedTitle, pass);
      }
      if (says('rate_limit_exceeded') ||
          res.json.containsKey('captcha_id') ||
          res.json.containsKey('captcha_image')) {
        return (
          l10n.amneziaErrorCaptchaAskedTitle,
          l10n.amneziaErrorCaptchaAskedDetail(pass),
        );
      }
      return (
        l10n.amneziaErrorNotActiveTitle,
        l10n.amneziaErrorNotActiveDetail,
      );
  }
  return (
    l10n.amneziaErrorRefusedTitle,
    l10n.amneziaErrorRefusedHttpDetail(res.httpStatus),
  );
}
