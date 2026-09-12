import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

import '../api/api_client.dart';
import 'oidc_login.dart';

/// A message in the two parts the UI always shows: what happened, and what to
/// do about it. Exception text never reaches either — it goes to the log.
///
/// Which of the two formats carries it — a toast that leaves on its own or a
/// modal dialog — is the caller's call, since only the caller knows whether the
/// user can still act on it. See [showToast] and [showErrorDialog].
class AppError {
  const AppError(this.title, {this.detail});

  final String title;
  final String? detail;

  /// Single line for a toast, where there is no room for two.
  String get line => detail == null ? title : '$title — $detail';
}

/// An error that already knows how to present itself, thrown by a layer that
/// understood exactly what went wrong. [describeError] passes it through
/// untouched, so a precise diagnosis is never flattened into a generic one.
class AppErrorException implements Exception {
  const AppErrorException(this.error);

  final AppError error;

  @override
  String toString() => error.line;
}

/// The provider refused this device because its device limit is full.
///
/// Its own message travels in the entries it sends instead of servers, so this
/// says the one thing those entries cannot: what to do about it.
const kDeviceLimitReached = AppError(
  'Device limit reached',
  detail:
      'Your subscription’s device limit is full, so it sent a placeholder '
      'instead of your servers. Free a slot in your subscription, then refresh.',
);

/// A subscription body that produced no usable servers, with the reason already
/// worded for the user and, when we know it, a page to send them to.
///
/// Still a [FormatException]: the add flow uses that type to decide whether the
/// URL might be a management server instead, and a precise diagnosis must not
/// cost the user the sign-in path.
class SubscriptionFormatException extends FormatException {
  SubscriptionFormatException(this.error, {this.openUrl}) : super(error.line);

  final AppError error;

  /// The provider's own page, when the panel named one. Where a person can see
  /// what the app could not use.
  final String? openUrl;
}

/// The panel answered with something that is not a server list we can read.
///
/// Naming the formats we do read is not developer detail: it is what turns
/// "it does not work" into a sentence the user can take to their provider,
/// who is the only party who can change the template.
const kUnreadableSubscription = AppError(
  'Couldn’t read this subscription',
  detail:
      'Your subscription sent a format this app does not recognise. It reads '
      'base64 link lists, Clash / mihomo, Xray JSON and sing-box. Nothing was added.',
);

/// The format was read and there are no servers in it at all.
///
/// A real answer from a panel, not a malformed one: an expired account, a full
/// device limit or a user with nothing assigned all produce an empty list. The
/// fix is with the provider, so the message says so instead of blaming the
/// format.
AppError emptySubscription(String what) => AppError(
  'This subscription has no servers',
  detail:
      'Your subscription answered with $what that lists none. That usually '
      'means the account is out of days or its device limit is full — ask them.',
);

/// The body was read and every server in it uses something we cannot run.
///
/// Distinct from [kUnreadableSubscription] on purpose: here we can count them
/// and name what they use, which is a different problem with a different fix.
AppError noRunnableServers(int total, String kinds) => AppError(
  total == 1
      ? 'The only server here cannot run'
      : 'None of the $total servers can run here',
  detail: 'They use $kinds, which this app cannot run yet. Nothing was added.',
);

/// The panel sent entries that are not servers at all — every address is
/// unroutable — and put its message in their names.
///
/// Seen on a live panel answering an unknown client. Importing them would give
/// the user locations that can never connect; the honest reading is that this
/// is text, so it is shown as text.
AppError providerMessageInstead(Iterable<String> lines) => AppError(
  'Your subscription sent a message',
  detail:
      '${lines.where((l) => l.trim().isNotEmpty).join('\n')}'
      '\n\nNot servers: every entry points nowhere, so nothing was added.',
);

/// Translates whatever the layers below threw into something a person can act
/// on. [subject] names what failed — a host, a subscription URL — so the second
/// line can be specific instead of "connection error".
AppError describeError(Object error, {String? subject}) {
  final what = subject ?? 'the server';

  AppError err(String title, String? detail) => AppError(title, detail: detail);

  return switch (error) {
    // A diagnosis made where the body was read, already worded — never
    // flattened into the generic "doesn't look like a link" below.
    SubscriptionFormatException(:final error) => error,
    AppErrorException(:final error) => error,
    SocketException() || TimeoutException() => err(
      'Server didn’t answer',
      'Couldn’t reach $what. Check your network, or pick another server.',
    ),
    HandshakeException() || TlsException() => err(
      'Couldn’t set up a secure connection',
      'The certificate of $what was rejected. If the address is right, the server may be misconfigured.',
    ),
    HttpException() => err(
      'Server didn’t answer',
      'The connection to $what was closed.',
    ),
    ApiException(status: 401, code: 'invalid_credentials') => err(
      'Wrong username or password',
      'Check both and try again.',
    ),
    ApiException(status: 401) => err(
      'Session expired',
      'Sign in to $what again.',
    ),
    ApiException(status: 403) => err(
      'Access is blocked',
      'The server refused this account.',
    ),
    ApiException(status: 404) => err(
      'Nothing at this address',
      'Check the link — $what has no configuration for this account.',
    ),
    ApiException(status: >= 500) => err(
      'The server returned an error',
      'Nothing to fix on this side — try again in a few minutes.',
    ),
    ApiException(message: final m) => err('The server refused the request', m),
    // A parse failure, and only that. Anything that already has words for the
    // user throws [AppErrorException]; a FormatException carrying a sentence
    // would land here and be replaced by this one.
    FormatException() => err(
      'This doesn’t look like a link we know',
      'Expected vless://, vmess://, trojan://, ss:// or a subscription URL.',
    ),
    // The Windows tunnel is a service the app does not own. Absent (not
    // installed, stopped) and vanished mid-request are different situations
    // with different fixes, and neither has anything to do with a VPN profile.
    PlatformException(code: 'service_unavailable') => err(
      'The tunnel service isn’t running',
      'AnnoyaTest installs it as the “AnnoyaTunnel” Windows service. Reinstall the app, '
          'or start the service in Services, then connect again.',
    ),
    PlatformException(code: 'service_disconnected') => err(
      'The tunnel service stopped',
      'It restarts on its own within a few seconds — connect again. If this keeps '
          'happening, the tunnel log in Settings → Logs says why.',
    ),
    // NEVPNError / permission denial arrives as a channel error.
    PlatformException() => err(
      'The system refused to start the tunnel',
      'Allow the VPN profile in system settings, then connect again.',
    ),
    OidcException() => err(
      'Sign-in didn’t finish',
      'The browser window was closed or the provider refused.',
    ),
    _ => err('Something went wrong', 'The details are in Settings → Logs.'),
  };
}

/// Why an account cannot connect, in the user's terms rather than the server's
/// status enum.
AppError describeAccountStatus(String status) => switch (status) {
  'expired' => const AppError(
    'Subscription expired',
    detail: 'Renew it in your account, then connect again.',
  ),
  'limited' => const AppError(
    'Traffic limit reached',
    detail: 'The plan is used up until it renews.',
  ),
  // The server's stored status is "deactivated" (shared/normconfig).
  'deactivated' => const AppError(
    'Access disabled',
    detail: 'The administrator turned this account off.',
  ),
  'on_hold' => const AppError(
    'Subscription not started',
    detail: 'It begins on the first connection — try again in a moment.',
  ),
  _ => AppError(
    'Account is ${status.replaceAll('_', ' ')}',
    detail: 'Connecting is not allowed in this state.',
  ),
};
