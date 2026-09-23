import '../../l10n/l10n.dart';
import '../app_error.dart';
import 'agw_ffi.dart';

/// What a gateway failure means to the person holding the subscription.
///
/// Two kinds of failure, told apart by the library: the transport never got an
/// answer (a code in [AgwStatus]), or the gateway answered and refused, with
/// its `http_status` and `message` in the body. Which refusal it is follows
/// the reference client's reading of the same statuses (`apiUtils::
/// checkApiResponseErrors`), so a user who reads the same sentence in two
/// clients is looking at the same problem. What is added here is the second
/// line — what to do — which the reference client mostly leaves to a support
/// chat; the gateway's own sentence, when it sent one, wins over ours.
///
/// Nothing here names Amnezia, on purpose. The same key format and the same
/// gateway serve other sellers — a key can arrive carrying someone else's name
/// entirely — so a sentence that named one of them would be wrong for everyone
/// else holding the same kind of subscription. Nor is anything attributed to
/// "your provider": SPEC-CLIENT §5 gives everything a subscription supplies to
/// *the subscription*, because there is no account behind it and naming a
/// company invents a party the app has no relationship with.
///
/// A code or status we do not recognise is reported as itself rather than
/// folded into "something went wrong": an unexplained number the user can
/// quote to support is worth more than a sentence that fits every failure.
AppError describeAmneziaError(AgwResponse res) {
  final (title, ours) = res.code == AgwStatus.ok
      ? _refusal(res)
      : _transport(res.code);
  final theirs = res.message;
  return AppError(title, detail: theirs.isNotEmpty ? theirs : ours);
}

/// The gateway answered, but not with a configuration: an empty or unreadable
/// document. Not a refusal — it said nothing about why.
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

/// The gateway's refusals, by the status it wrote into its document. The
/// statuses and the message fragments that split them are the gateway's
/// contract as the reference client reads it; a status outside this list is
/// quoted, not guessed at.
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
      // The captcha family: the client this subscription came from can show
      // and solve one, and this app deliberately cannot — so it says which
      // door is open rather than offering a control that does nothing.
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
