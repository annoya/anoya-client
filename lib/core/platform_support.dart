import 'package:flutter/foundation.dart';

bool get supportsProcessRules => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

bool get supportsOnDemand => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => true,
  _ => false,
};

bool get supportsBootAutoConnect => switch (defaultTargetPlatform) {
  TargetPlatform.windows || TargetPlatform.linux => true,
  _ => false,
};

bool get canShareFiles => defaultTargetPlatform != TargetPlatform.linux;

bool get hasAutoConnect => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.iOS ||
  TargetPlatform.android ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};
