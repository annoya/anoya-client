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
  detail: 'Your provider’s device limit is full, so it sent a placeholder '
      'instead of your servers. Free a slot with your provider, then refresh.',
);

/// Translates whatever the layers below threw into something a person can act
/// on. [subject] names what failed — a host, a subscription URL — so the second
/// line can be specific instead of "connection error".
AppError describeError(Object error, {String? subject}) {
  final what = subject ?? 'the server';

  AppError err(String title, String? detail) => AppError(title, detail: detail);

  return switch (error) {
    AppErrorException(:final error) => error,
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
      // The server's stored status is "deactivated" (shared/normconfig).
      'deactivated' => const AppError('Access disabled',
          detail: 'The administrator turned this account off.'),
      'on_hold' => const AppError('Subscription not started',
          detail: 'It begins on the first connection — try again in a moment.'),
      _ => AppError('Account is ${status.replaceAll('_', ' ')}',
          detail: 'Connecting is not allowed in this state.'),
    };
