import 'package:flutter/foundation.dart';

int androidSdk = 0;

bool isTv = false;

const kAndroidOwnerLookupSdk = 29;

bool get supportsProcessRules => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  TargetPlatform.android => androidSdk >= kAndroidOwnerLookupSdk,
  _ => false,
};

bool get processRulesPickApps =>
    defaultTargetPlatform == TargetPlatform.android;

bool get supportsExcludedApps =>
    defaultTargetPlatform == TargetPlatform.android;

bool get supportsOnDemand => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => true,
  _ => false,
};

bool get supportsBootAutoConnect => switch (defaultTargetPlatform) {
  TargetPlatform.windows || TargetPlatform.linux => true,
  _ => false,
};

bool get canShareFiles => defaultTargetPlatform != TargetPlatform.linux;

bool get canScanQr => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => true,
  TargetPlatform.android => !isTv,
  _ => false,
};

bool get canOpenFiles => !isTv;

bool get isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

bool get hasDnsProtection => switch (defaultTargetPlatform) {
  TargetPlatform.windows || TargetPlatform.linux => true,
  _ => false,
};

bool get hasAutoConnect => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.iOS ||
  TargetPlatform.android ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};
