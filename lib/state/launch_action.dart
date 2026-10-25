import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network_extension_core.dart';

const kLaunchServerPicker = 'server_picker';

class LaunchActionController extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> check() async {
    final String? action;
    try {
      action = await NetworkExtensionCore.control.invoke<String>(
        'take_launch_action',
      );
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
    if (action != null && ref.mounted) state = action;
  }

  void consume() => state = null;

  void take(String action) => state = action;
}

final launchActionProvider = NotifierProvider<LaunchActionController, String?>(
  LaunchActionController.new,
);
