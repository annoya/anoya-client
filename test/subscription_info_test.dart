import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/subscription_info.dart';

void main() {
  test('a plan with a quota and an end date', () {
    final info = SubscriptionInfo.fromHeaders({
      'profile-title': 'base64:0JrQntCf0JDQotCr0KcgVlBO',
      'subscription-userinfo':
          'upload=100; download=900; total=2000; expire=1785093975',
      'profile-update-interval': '1',
      'support-url': 'https://t.me/example_bot',
      'profile-web-page-url': 'https://panel.example/s/abc',
    });
    expect(
      info.title,
      'КОПАТЫЧ VPN',
      reason: 'titles arrive base64 when not ASCII',
    );
    expect(info.usedBytes, 1000, reason: 'used is upload + download');
    expect(info.totalBytes, 2000);
    expect(info.unlimited, isFalse);
    expect(info.expiresAt!.toUtc(), DateTime.utc(2026, 7, 26, 19, 26, 15));
    expect(info.updateInterval, 1);
    expect(info.supportUrl, 'https://t.me/example_bot');
    expect(info.webPageUrl, 'https://panel.example/s/abc');
  });

  test('total=0 and expire=0 mean no limit and no end, not zero left', () {
    final info = SubscriptionInfo.fromHeaders({
      'subscription-userinfo':
          'upload=0; download=257821930181; total=0; expire=0',
    });
    expect(info.unlimited, isTrue);
    expect(info.expiresAt, isNull);
    expect(info.expired, isFalse);
    expect(info.usedBytes, 257821930181);
  });

  test('a message from the provider is decoded, newlines and all', () {
    final info = SubscriptionInfo.fromHeaders({
      'announce':
          'base64:0JrQntCf0JDQotCr0Kcg0JLQn9CdIOKAlCDQuNC90YLQtdGA0L3QtdGCINCx0LXQtyDRgdC+0YDQvdGP0LrQvtCyCkBrb3BhdHljaHZwbl9ib3Q=',
    });
    expect(
      info.announce,
      'КОПАТЫЧ ВПН — интернет без сорняков\n@kopatychvpn_bot',
    );
  });

  test('a plain (non-base64) title is taken as-is', () {
    expect(
      SubscriptionInfo.fromHeaders({'profile-title': 'My VPN'}).title,
      'My VPN',
    );
  });

  test('undecodable base64 costs the field, not the whole response', () {
    final info = SubscriptionInfo.fromHeaders({
      'profile-title': 'base64:!!!not base64!!!',
      'subscription-userinfo': 'upload=1; download=1; total=10; expire=0',
    });
    expect(info.title, '');
    expect(info.usedBytes, 2, reason: 'the rest of the headers still parse');
  });

  test('a panel that says nothing yields nothing to show', () {
    final info = SubscriptionInfo.fromHeaders(const {});
    expect(info.isEmpty, isTrue);
    expect(info.hasPlan, isFalse);
  });

  test('an expired plan is reported as expired, never enforced', () {
    final past = DateTime.now().subtract(const Duration(days: 20));
    final info = SubscriptionInfo.fromHeaders({
      'subscription-userinfo':
          'upload=0; download=0; total=100; expire=${past.millisecondsSinceEpoch ~/ 1000}',
    });
    expect(info.expired, isTrue);
  });

  test('the whole thing round-trips through storage', () {
    final info = SubscriptionInfo.fromHeaders({
      'profile-title': 'Sub',
      'subscription-userinfo':
          'upload=1; download=2; total=9; expire=1785093975',
      'announce': 'hello',
      'support-url': 'https://s.example',
      'profile-web-page-url': 'https://w.example',
      'profile-update-interval': '12',
    });
    final back = SubscriptionInfo.fromJson(info.toJson());
    expect(back.title, info.title);
    expect(back.usedBytes, info.usedBytes);
    expect(back.totalBytes, info.totalBytes);
    expect(back.expiresAt, info.expiresAt);
    expect(back.announce, info.announce);
    expect(back.supportUrl, info.supportUrl);
    expect(back.webPageUrl, info.webPageUrl);
    expect(back.updateInterval, info.updateInterval);
  });
}
