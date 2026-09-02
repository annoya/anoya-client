import '../app_error.dart';
import 'agw_ffi.dart';

/// What a gateway refusal means to the person holding the subscription.
///
/// The codes are the gateway's, and so is the wording where it already has it:
/// a user who reads the same sentence in two clients knows they are looking at
/// the same problem. What is added here is the second line — what to do — which
/// the reference client mostly leaves to a support chat.
///
/// Nothing here names Amnezia, on purpose. The same key format and the same
/// gateway serve other sellers — a key can arrive carrying someone else's name
/// entirely — so a sentence that named one of them would be wrong for everyone
/// else holding the same kind of subscription. Nor is anything attributed to
/// "your provider": SPEC-CLIENT §5 gives everything a subscription supplies to
/// *the subscription*, because there is no account behind it and naming a
/// company invents a party the app has no relationship with.
///
/// A code we do not recognise is reported as itself rather than folded into
/// "something went wrong": an unexplained number the user can quote to support
/// is worth more than a sentence that fits every failure.
AppError describeAmneziaError(int code, {String? detail}) {
  final known = _messages[code];
  if (known != null) {
    return AppError(known.$1, detail: detail?.isNotEmpty == true ? detail : known.$2);
  }
  return AppError('The gateway refused the request',
      detail: detail?.isNotEmpty == true
          ? detail
          : 'The gateway answered with code $code.');
}

const _messages = <int, (String, String)>{
  AgwStatus.cancelled: (
    'Took too long',
    'The gateway did not answer in time. Check the connection and try again.',
  ),
  AgwStatus.downloadError: (
    'Couldn’t reach the gateway',
    'The gateway did not answer. This is usually the network, not the '
        'subscription — try again in a moment.',
  ),
  AgwStatus.alreadyAdded: (
    'Already added',
    'This subscription is already on this device.',
  ),
  AgwStatus.emptyConfig: (
    'The gateway sent nothing',
    'It answered without a configuration. Try again; if it repeats, support '
        'for this subscription will need to look.',
  ),
  AgwStatus.timeout: (
    'The gateway timed out',
    'No answer within the time allowed. Check the connection and try again.',
  ),
  AgwStatus.sslError: (
    'The connection was not trusted',
    'Something interfered with the secure connection to the gateway.',
  ),
  AgwStatus.missingPublicKey: (
    'This build cannot talk to the gateway',
    'It was built without the gateway credentials, so subscriptions of this '
        'kind are unavailable in it.',
  ),
  AgwStatus.decryptionError: (
    'The answer could not be read',
    'The reply was not what the gateway should have sent — often a network '
        'that intercepts traffic.',
  ),
  AgwStatus.servicesMissing: (
    'No services offered',
    'The gateway returned no services for this subscription.',
  ),
  AgwStatus.configLimit: (
    'Device limit reached',
    'This subscription is already installed on as many devices as it allows. '
        'Remove one from the subscription, then try again.',
  ),
  AgwStatus.notFound: (
    'Subscription not found',
    'The gateway does not recognise this key. Check that it was pasted whole.',
  ),
  AgwStatus.migration: (
    'This subscription needs migrating',
    'The app it came from has to move it before it can be used here.',
  ),
  AgwStatus.updateRequired: (
    'The gateway requires a newer client',
    'The gateway refused this app’s version. It will work again once the app '
        'is updated.',
  ),
  AgwStatus.subscriptionExpired: (
    'Subscription expired',
    'Renew the subscription, then refresh this configuration.',
  ),
  AgwStatus.purchaseError: (
    'The purchase could not be processed',
    'The gateway could not complete it. Nothing was changed here.',
  ),
  AgwStatus.subscriptionNotActive: (
    'Subscription not active',
    'The gateway has no active subscription for this key.',
  ),
  AgwStatus.noPurchasedSubscriptions: (
    'No subscription on this account',
    'Buy a subscription first.',
  ),
  AgwStatus.trialAlreadyUsed: (
    'Trial already used',
    'This address has already activated a trial.',
  ),
  // The captcha family: the client this subscription came from can show and
  // solve one, and this app deliberately cannot — so it says which door is
  // open rather than offering a control that does nothing.
  AgwStatus.captchaRequired: (
    'The gateway asked for a CAPTCHA',
    'This app cannot show one. Pass it in the app this subscription came from, '
        'then refresh here.',
  ),
  AgwStatus.captchaInvalid: (
    'The CAPTCHA was rejected',
    'Pass it in the app this subscription came from, then refresh here.',
  ),
  AgwStatus.captchaRefresh: (
    'The CAPTCHA expired',
    'Pass it in the app this subscription came from, then refresh here.',
  ),
  AgwStatus.rateLimit: (
    'Too many requests',
    'The gateway is throttling this subscription. Wait a few minutes before '
        'trying again.',
  ),
};
