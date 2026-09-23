import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

import '../api/api_client.dart';
import '../l10n/l10n.dart';
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
AppError get kDeviceLimitReached => AppError(
  L10n.current.errorDeviceLimitTitle,
  detail: L10n.current.errorDeviceLimitDetail,
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
AppError get kUnreadableSubscription => AppError(
  L10n.current.errorUnreadableSubscriptionTitle,
  detail: L10n.current.errorUnreadableSubscriptionDetail,
);

/// The format was read and there are no servers in it at all.
///
/// A real answer from a panel, not a malformed one: an expired account, a full
/// device limit or a user with nothing assigned all produce an empty list. The
/// fix is with the provider, so the message says so instead of blaming the
/// format.
AppError emptySubscription(String what) => AppError(
  L10n.current.errorEmptySubscriptionTitle,
  detail: L10n.current.errorEmptySubscriptionDetail(what),
);

/// The body was read and every server in it uses something we cannot run.
///
/// Distinct from [kUnreadableSubscription] on purpose: here we can count them
/// and name what they use, which is a different problem with a different fix.
AppError noRunnableServers(int total, String kinds) => AppError(
  L10n.current.errorNoRunnableServersTitle(total),
  detail: L10n.current.errorNoRunnableServersDetail(kinds),
);

/// The panel sent entries that are not servers at all — every address is
/// unroutable — and put its message in their names.
///
/// Seen on a live panel answering an unknown client. Importing them would give
/// the user locations that can never connect; the honest reading is that this
/// is text, so it is shown as text.
AppError providerMessageInstead(Iterable<String> lines) => AppError(
  L10n.current.errorProviderMessageTitle,
  detail: L10n.current.errorProviderMessageDetail(
    lines.where((l) => l.trim().isNotEmpty).join('\n'),
  ),
);

/// Translates whatever the layers below threw into something a person can act
/// on. [subject] names what failed — a host, a subscription URL — so the second
/// line can be specific instead of "connection error".
AppError describeError(Object error, {String? subject}) {
  final l10n = L10n.current;
  final what = subject ?? l10n.errorSubjectDefault;

  AppError err(String title, String? detail) => AppError(title, detail: detail);

  return switch (error) {
    // A diagnosis made where the body was read, already worded — never
    // flattened into the generic "doesn't look like a link" below.
    SubscriptionFormatException(:final error) => error,
    AppErrorException(:final error) => error,
    SocketException() || TimeoutException() => err(
      l10n.errorServerDidNotAnswerTitle,
      l10n.errorCouldNotReachDetail(what),
    ),
    HandshakeException() || TlsException() => err(
      l10n.errorSecureConnectionTitle,
      l10n.errorCertificateRejectedDetail(what),
    ),
    HttpException() => err(
      l10n.errorServerDidNotAnswerTitle,
      l10n.errorConnectionClosedDetail(what),
    ),
    ApiException(status: 401, code: 'invalid_credentials') => err(
      l10n.errorWrongCredentialsTitle,
      l10n.errorWrongCredentialsDetail,
    ),
    ApiException(status: 401) => err(
      l10n.errorSessionExpiredTitle,
      l10n.errorSessionExpiredDetail(what),
    ),
    ApiException(status: 403) => err(
      l10n.errorAccessBlockedTitle,
      l10n.errorAccessBlockedDetail,
    ),
    ApiException(status: 404) => err(
      l10n.errorNothingAtAddressTitle,
      l10n.errorNothingAtAddressDetail(what),
    ),
    ApiException(status: >= 500) => err(
      l10n.errorServerErrorTitle,
      l10n.errorServerErrorDetail,
    ),
    ApiException(message: final m) => err(l10n.errorServerRefusedTitle, m),
    // A parse failure, and only that. Anything that already has words for the
    // user throws [AppErrorException]; a FormatException carrying a sentence
    // would land here and be replaced by this one.
    FormatException() => err(l10n.errorNotALinkTitle, l10n.errorNotALinkDetail),
    // The Windows and Linux tunnel is a service the app does not own. Absent
    // (not installed, stopped) and vanished mid-request are different
    // situations with different fixes, and neither has anything to do with a
    // VPN profile.
    PlatformException(code: 'service_unavailable') => err(
      l10n.errorTunnelServiceNotRunningTitle,
      Platform.isLinux
          ? l10n.errorTunnelServiceNotRunningDetailLinux
          : l10n.errorTunnelServiceNotRunningDetail,
    ),
    PlatformException(code: 'service_disconnected') => err(
      l10n.errorTunnelServiceStoppedTitle,
      l10n.errorTunnelServiceStoppedDetail,
    ),
    // NEVPNError / permission denial arrives as a channel error.
    PlatformException() => err(
      l10n.errorSystemRefusedTunnelTitle,
      l10n.errorSystemRefusedTunnelDetail,
    ),
    OidcException() => err(
      l10n.errorSignInNotFinishedTitle,
      l10n.errorSignInNotFinishedDetail,
    ),
    _ => err(
      l10n.errorSomethingWentWrongTitle,
      l10n.errorSomethingWentWrongDetail,
    ),
  };
}

/// Why an account cannot connect, in the user's terms rather than the server's
/// status enum.
AppError describeAccountStatus(String status) => switch (status) {
  'expired' => AppError(
    L10n.current.accountExpiredTitle,
    detail: L10n.current.accountExpiredDetail,
  ),
  'limited' => AppError(
    L10n.current.accountLimitedTitle,
    detail: L10n.current.accountLimitedDetail,
  ),
  // The server's stored status is "deactivated" (shared/normconfig).
  'deactivated' => AppError(
    L10n.current.accountDeactivatedTitle,
    detail: L10n.current.accountDeactivatedDetail,
  ),
  'on_hold' => AppError(
    L10n.current.accountOnHoldTitle,
    detail: L10n.current.accountOnHoldDetail,
  ),
  _ => AppError(
    L10n.current.accountOtherStateTitle(status.replaceAll('_', ' ')),
    detail: L10n.current.accountOtherStateDetail,
  ),
};
