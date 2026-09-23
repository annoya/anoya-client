import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import 'oidc_login.dart';

class AppError {
  const AppError(this.title, {this.detail});

  final String title;
  final String? detail;

  String get line => detail == null ? title : '$title — $detail';
}

class AppErrorException implements Exception {
  const AppErrorException(this.error);

  final AppError error;

  @override
  String toString() => error.line;
}

AppError get kDeviceLimitReached => AppError(
  L10n.current.errorDeviceLimitTitle,
  detail: L10n.current.errorDeviceLimitDetail,
);

class SubscriptionFormatException extends FormatException {
  SubscriptionFormatException(this.error, {this.openUrl}) : super(error.line);

  final AppError error;

  final String? openUrl;
}

AppError get kUnreadableSubscription => AppError(
  L10n.current.errorUnreadableSubscriptionTitle,
  detail: L10n.current.errorUnreadableSubscriptionDetail,
);

AppError emptySubscription(String what) => AppError(
  L10n.current.errorEmptySubscriptionTitle,
  detail: L10n.current.errorEmptySubscriptionDetail(what),
);

AppError noRunnableServers(int total, String kinds) => AppError(
  L10n.current.errorNoRunnableServersTitle(total),
  detail: L10n.current.errorNoRunnableServersDetail(kinds),
);

AppError providerMessageInstead(Iterable<String> lines) => AppError(
  L10n.current.errorProviderMessageTitle,
  detail: L10n.current.errorProviderMessageDetail(
    lines.where((l) => l.trim().isNotEmpty).join('\n'),
  ),
);

AppError describeError(Object error, {String? subject}) {
  final l10n = L10n.current;
  final what = subject ?? l10n.errorSubjectDefault;

  AppError err(String title, String? detail) => AppError(title, detail: detail);

  return switch (error) {
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
    FormatException() => err(l10n.errorNotALinkTitle, l10n.errorNotALinkDetail),
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

AppError describeAccountStatus(String status) => switch (status) {
  'expired' => AppError(
    L10n.current.accountExpiredTitle,
    detail: L10n.current.accountExpiredDetail,
  ),
  'limited' => AppError(
    L10n.current.accountLimitedTitle,
    detail: L10n.current.accountLimitedDetail,
  ),
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
