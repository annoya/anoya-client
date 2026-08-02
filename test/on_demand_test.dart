import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/on_demand.dart';

void main() {
  test('rule json round-trip keeps every field', () {
    const rule = OnDemandRule(
      id: 'r1',
      name: 'Office',
      action: OnDemandAction.disconnect,
      interface: OnDemandInterface.wifi,
      ssids: ['corp-net', 'corp-guest'],
      dnsDomains: ['corp.example.com'],
      dnsServers: ['10.0.*'],
      probeUrl: 'https://intranet.example.com/ping',
    );
    final restored = OnDemandRule.fromJson(rule.toJson());
    expect(restored.name, 'Office');
    expect(restored.action, OnDemandAction.disconnect);
    expect(restored.interface, OnDemandInterface.wifi);
    expect(restored.ssids, ['corp-net', 'corp-guest']);
    expect(restored.dnsDomains, ['corp.example.com']);
    expect(restored.dnsServers, ['10.0.*']);
    expect(restored.probeUrl, 'https://intranet.example.com/ping');
  });

  test('channel payload has the shape the Swift side compiles', () {
    const rule = OnDemandRule(
      id: 'r2',
      action: OnDemandAction.connect,
      interface: OnDemandInterface.wifi,
      ssids: ['home-5G'],
    );
    final ch = rule.toChannel();
    expect(ch['action'], 'connect');
    expect(ch['interface'], 'wifi');
    expect(ch['ssids'], ['home-5G']);
    expect(ch.containsKey('id'), false); // system rules carry no id/name
    expect(ch.containsKey('name'), false);
  });

  group('ssid only applies to Wi-Fi', () {
    const withSsid = OnDemandRule(id: 'r', ssids: ['corp-net']);

    test('kept for Wi-Fi and Any, dropped for cellular/ethernet', () {
      expect(withSsid.effectiveSsids, ['corp-net']); // any
      expect(withSsid.copyWith(interface: OnDemandInterface.wifi).effectiveSsids,
          ['corp-net']);
      expect(withSsid.copyWith(interface: OnDemandInterface.cellular).effectiveSsids,
          isEmpty);
      expect(withSsid.copyWith(interface: OnDemandInterface.ethernet).effectiveSsids,
          isEmpty);
    });

    test('never compiled into a rule the system could not satisfy', () {
      final mobile = withSsid.copyWith(interface: OnDemandInterface.cellular);
      expect(mobile.toChannel()['ssids'], isEmpty);
      expect(mobile.summary, 'Mobile');
    });

    test('values survive a round trip through another interface', () {
      final back = withSsid
          .copyWith(interface: OnDemandInterface.cellular)
          .copyWith(interface: OnDemandInterface.wifi);
      expect(back.effectiveSsids, ['corp-net'],
          reason: 'switching modes must not throw the list away');
    });
  });

  test('summary names the conditions', () {
    const rule = OnDemandRule(
      id: 'r3',
      interface: OnDemandInterface.wifi,
      ssids: ['corp-net'],
      dnsServers: ['10.0.*'],
    );
    expect(rule.summary, 'Wi-Fi · SSID corp-net · DNS 10.0.*');
    expect(const OnDemandRule(id: 'r4').summary, 'Any network');
  });

  group('prefs', () {
    test('armed requires enabled, not paused and at least one rule', () {
      const rule = OnDemandRule(id: 'r');
      expect(const OnDemandPrefs(enabled: true, rules: [rule]).armed, true);
      expect(const OnDemandPrefs(enabled: true, paused: true, rules: [rule]).armed, false);
      expect(const OnDemandPrefs(enabled: true).armed, false);
      expect(const OnDemandPrefs(rules: [rule]).armed, false);
    });

    test('status label reflects off / paused / awaiting / rule count', () {
      const rule = OnDemandRule(id: 'r');
      expect(const OnDemandPrefs().statusLabel, 'Off');
      expect(const OnDemandPrefs(enabled: true, paused: true, rules: [rule]).statusLabel,
          'Paused');
      // Enabled but the system hasn't taken it (no persisted tunnel config yet).
      expect(const OnDemandPrefs(enabled: true, rules: [rule]).statusLabel,
          'On · after first connect');
      expect(
          const OnDemandPrefs(enabled: true, rules: [rule, rule], systemArmed: true).statusLabel,
          'On · 2 rules');
    });

    test('awaitingFirstConnect only while asked-for but not system-armed', () {
      const rule = OnDemandRule(id: 'r');
      expect(const OnDemandPrefs(enabled: true, rules: [rule]).awaitingFirstConnect, true);
      expect(
          const OnDemandPrefs(enabled: true, rules: [rule], systemArmed: true)
              .awaitingFirstConnect,
          false);
      // Paused isn't "awaiting" — it's a deliberate stop.
      expect(
          const OnDemandPrefs(enabled: true, paused: true, rules: [rule]).awaitingFirstConnect,
          false);
    });

    test('systemArmed is runtime state, never persisted', () {
      const prefs = OnDemandPrefs(enabled: true, rules: [OnDemandRule(id: 'r')], systemArmed: true);
      expect(prefs.toJson().containsKey('system_armed'), false);
      // A reload starts from "not armed" until the platform confirms.
      expect(OnDemandPrefs.fromJson(prefs.toJson()).systemArmed, false);
    });

    test('prefs json round-trip', () {
      const prefs = OnDemandPrefs(
        enabled: true,
        paused: true,
        disconnectOnSleep: true,
        rules: [OnDemandRule(id: 'a', action: OnDemandAction.ignore)],
      );
      final restored = OnDemandPrefs.fromJson(prefs.toJson());
      expect(restored.enabled, true);
      expect(restored.paused, true);
      expect(restored.disconnectOnSleep, true);
      expect(restored.rules.single.action, OnDemandAction.ignore);
    });
  });
}
