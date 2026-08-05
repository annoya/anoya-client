import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

import '../api/api_client.dart';
import 'oidc_login.dart';

/// How a message is shown. The question that decides it: can the user act on
/// this? A failed refresh is over and done with — a toast. A tunnel that would
/// not come up needs a decision, so it stays until dismissed.
enum ErrorLevel { toast, banner }

/// A message in the two parts the UI always shows: what happened, and what to
/// do about it. Exception text never reaches either — it goes to the log.
class AppError {
  const AppError(this.title, {this.detail, this.level = ErrorLevel.banner});

  final String title;
  final String? detail;
  final ErrorLevel level;

  /// Single line for a toast, where there is no room for two.
  String get line => detail == null ? title : '$title — $detail';

  AppError asToast() => AppError(title, detail: detail, level: ErrorLevel.toast);
}

/// Translates whatever the layers below threw into something a person can act
/// on. [subject] names what failed — a host, a subscription URL — so the second
/// line can be specific instead of "connection error".
AppError describeError(Object error, {String? subject, ErrorLevel level = ErrorLevel.banner}) {
  final what = subject ?? 'the server';

  AppError err(String title, String? detail) =>
      AppError(title, detail: detail, level: level);

  return switch (error) {
    SocketException() || TimeoutException() => err(
        'Server didn’t answer',
        'Couldn’t reach $what. Check your network, or pick another server.',
      ),
    HandshakeException() || TlsException() => err(
        'Couldn’t set up a secure connection',
        'The certificate of $what was rejected. If the address is right, the server may be misconfigured.',
      ),
    HttpException() => err('Server didn’t answer', 'The connection to $what was closed.'),
    ApiException(status: 401, code: 'invalid_credentials') =>
      err('Wrong username or password', 'Check both and try again.'),
    ApiException(status: 401) => err('Session expired', 'Sign in to $what again.'),
    ApiException(status: 403) => err('Access is blocked', 'The server refused this account.'),
    ApiException(status: 404) => err(
        'Nothing at this address',
        'Check the link — $what has no configuration for this account.',
      ),
    ApiException(status: >= 500) =>
      err('The server returned an error', 'Nothing to fix on this side — try again in a few minutes.'),
    ApiException(message: final m) => err('The server refused the request', m),
    FormatException() => err(
        'This doesn’t look like a link we know',
        'Expected vless://, vmess://, trojan://, ss:// or a subscription URL.',
      ),
    // NEVPNError / permission denial arrives as a channel error.
    PlatformException() => err(
        'The system refused to start the tunnel',
        'Allow the VPN profile in system settings, then connect again.',
      ),
    OidcException() => err('Sign-in didn’t finish', 'The browser window was closed or the provider refused.'),
    _ => err('Something went wrong', 'The details are in Settings → Logs.'),
  };
}

/// Why an account cannot connect, in the user's terms rather than the server's
/// status enum.
AppError describeAccountStatus(String status) => switch (status) {
      'expired' => const AppError('Subscription expired',
          detail: 'Renew it in your account, then connect again.'),
      'limited' => const AppError('Traffic limit reached',
          detail: 'The plan is used up until it renews.'),
      'disabled' => const AppError('Access disabled',
          detail: 'The administrator turned this account off.'),
      'on_hold' => const AppError('Subscription not started',
          detail: 'It begins on the first connection — try again in a moment.'),
      _ => AppError('Account is ${status.replaceAll('_', ' ')}',
          detail: 'Connecting is not allowed in this state.'),
    };
