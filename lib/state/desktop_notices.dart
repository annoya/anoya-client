import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/network_extension_core.dart';
import '../core/tunnel_notice.dart';
import 'launch_action.dart';
import 'profiles_controller.dart';

const kNoticeSilent = 'silent';
const kNoticeAnswers = 'answers';
const kNoticeStartFailed = 'start_failed';

class DesktopNotices {
  DesktopNotices(this._ref, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vpn/notify');

  final Ref _ref;
  final MethodChannel _channel;
  StreamSubscription<String>? _sub;

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'clicked' && call.arguments is String) {
        _ref.read(launchActionProvider.notifier).take(call.arguments as String);
      }
      return null;
    });
    _sub = NetworkExtensionCore.control.noticeEvents.listen(handle);
  }

  void dispose() {
    _sub?.cancel();
    _channel.setMethodCallHandler(null);
  }

  Future<void> handle(String notice) async {
    final profiles = _ref.read(profilesControllerProvider);
    final texts = tunnelNotice(
      configuration: profiles.active?.name ?? '',
      server: profiles.active?.usesSubscriptionRules ?? false
          ? profiles.active!.name
          : profiles.selectedGroup?.name ??
                profiles.selectedLocation?.label ??
                '',
    );
    try {
      switch (notice) {
        case kNoticeSilent:
          await _channel.invokeMethod<void>('notify', {
            'id': kNoticeSilent,
            'title': texts['silent_title'],
            'body': texts['silent_body'],
            'action': kLaunchServerPicker,
          });
        case kNoticeAnswers:
          await _channel.invokeMethod<void>('withdraw', {'id': kNoticeSilent});
        case kNoticeStartFailed:
          await _channel.invokeMethod<void>('notify', {
            'id': kNoticeStartFailed,
            'title': texts['start_failed_title'],
            'body': texts['start_failed_body'],
          });
      }
    } on PlatformException catch (e) {
      Log.e('notification not shown', e.message ?? e.code);
    } on MissingPluginException {
      return;
    }
  }
}

final desktopNoticesProvider = Provider<DesktopNotices>((ref) {
  final notices = DesktopNotices(ref)..start();
  ref.onDispose(notices.dispose);
  return notices;
});
