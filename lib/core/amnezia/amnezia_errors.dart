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
const kAmneziaEmptyAnswer = AppError(
  'The gateway sent nothing',
  detail:
      'It answered without a configuration. Try again; if it repeats, support '
      'for this subscription will need to look.',
);

(String, String) _transport(int code) => switch (code) {
  AgwStatus.cancelled => (
    'Took too long',
    'The gateway did not answer in time. Check the connection and try again.',
  ),
  AgwStatus.network => (
    'Couldn’t reach the gateway',
    'The gateway did not answer. This is usually the network, not the '
        'subscription — try again in a moment.',
  ),
  AgwStatus.timeout => (
    'The gateway timed out',
    'No answer within the time allowed. Check the connection and try again.',
  ),
  AgwStatus.ssl => (
    'The connection was not trusted',
    'Something interfered with the secure connection to the gateway.',
  ),
  AgwStatus.config => (
    'This build cannot talk to the gateway',
    'It was built without the gateway credentials, so subscriptions of this '
        'kind are unavailable in it.',
  ),
  AgwStatus.decrypt => (
    'The answer could not be read',
    'The reply was not what the gateway should have sent — often a network '
        'that intercepts traffic.',
  ),
  AgwStatus.invalidArgument => (
    'The gateway request was malformed',
    'A defect in this app, not in the subscription. Restarting the app helps; '
        'if it repeats, the log in Settings → Logs is what support needs.',
  ),
  _ => (
    'The gateway refused the request',
    'The gateway answered with code $code.',
  ),
};

/// The gateway's refusals, by the status it wrote into its document. The
/// statuses and the message fragments that split them are the gateway's
/// contract as the reference client reads it; a status outside this list is
/// quoted, not guessed at.
(String, String) _refusal(AgwResponse res) {
  final message = res.message.toLowerCase();
  bool says(String needle) => message.contains(needle);
  switch (res.httpStatus) {
    case 429:
      return (
        'Too many requests',
        'The gateway is throttling this subscription. Wait a few minutes before '
            'trying again.',
      );
    case 409:
      if (says('trial subscription already used')) {
        return (
          'Trial already used',
          'This address has already activated a trial.',
        );
      }
      return (
        'Device limit reached',
        'This subscription is already installed on as many devices as it allows. '
            'Remove one from the subscription, then try again.',
      );
    case 404:
      return (
        'Subscription not found',
        'The gateway does not recognise this key. Check that it was pasted whole.',
      );
    case 408:
      return (
        'The gateway timed out',
        'No answer within the time allowed. Check the connection and try again.',
      );
    case 501:
      return (
        'The gateway requires a newer client',
        'The gateway refused this app’s version. It will work again once the app '
            'is updated.',
      );
    case 422:
      if (says('failed to retrieve subscription information')) {
        return (
          'Subscription expired',
          'Renew the subscription, then refresh this configuration.',
        );
      }
    case 402:
      // The captcha family: the client this subscription came from can show
      // and solve one, and this app deliberately cannot — so it says which
      // door is open rather than offering a control that does nothing.
      const pass =
          'Pass it in the app this subscription came from, then refresh here.';
      if (says('refresh_captcha')) return ('The CAPTCHA expired', pass);
      if (says('invalid_captcha')) return ('The CAPTCHA was rejected', pass);
      if (says('rate_limit_exceeded') ||
          res.json.containsKey('captcha_id') ||
          res.json.containsKey('captcha_image')) {
        return (
          'The gateway asked for a CAPTCHA',
          'This app cannot show one. $pass',
        );
      }
      return (
        'Subscription not active',
        'The gateway has no active subscription for this key.',
      );
  }
  return (
    'The gateway refused the request',
    'The gateway answered with HTTP ${res.httpStatus}.',
  );
}
