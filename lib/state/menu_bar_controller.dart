import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/menu_bar.dart';
import '../core/profile.dart';
import '../core/vpn_core.dart';
import 'profiles_controller.dart';
import 'session.dart';

/// Keeps the macOS menu bar item and the Windows tray icon in step with the
/// app, and runs what they ask.
///
/// Watched by the app shell so it lives as long as the app does — the menu has
/// to work while the window is closed, which is precisely when no screen is
/// watching anything.
final menuBarProvider = Provider<MenuBar>((ref) {
  final menu = MenuBar();
  if (!MenuBar.supported) return menu;

  final profiles = ref.read(profilesControllerProvider.notifier);
  menu.onConnect = profiles.connect;
  menu.onDisconnect = profiles.disconnect;
  // The menu asks on every open because the session clock runs here; what it
  // gets back is composed from whatever is current at that moment.
  menu.onSync = () => _push(ref, menu);
  menu.start();

  ref.listen(sessionProvider, (_, _) => _push(ref, menu), fireImmediately: true);
  ref.listen(profilesControllerProvider, (_, _) => _push(ref, menu));
  ref.onDispose(menu.dispose);
  return menu;
});

void _push(Ref ref, MenuBar menu) => menu.update(
      menuBarStateFor(ref.read(sessionProvider), ref.read(profilesControllerProvider)),
    );

/// What the menu should say, given what the app knows.
///
/// Pure, and tested as such: the wording is the whole feature here — an item
/// that offers "Connect" with nothing to connect to, or a status line that
/// claims a tunnel the app does not have, is the only way this can mislead.
MenuBarState menuBarStateFor(SessionState session, ProfilesState profiles) {
  final Profile? active = profiles.active;
  final location = profiles.selectedLocation;

  if (active == null) {
    // Nothing to connect to, and saying so is what makes the disabled items
    // legible: the reason is on screen instead of left to be guessed.
    return const MenuBarState(status: 'No configuration');
  }

  final where = location == null ? '' : ' · ${location.label}';
  final clock = sessionClock(session.startedAt);
  final status = switch (session.status) {
    // A hot switch keeps the session up, so the word for it is not
    // "connecting" — the same distinction the home screen makes.
    _ when profiles.switching => 'Switching…$where',
    VpnStatus.connected => 'Connected$where',
    VpnStatus.connecting => 'Connecting…$where',
    VpnStatus.error => 'Error',
    VpnStatus.disconnected => 'Not connected',
  };

  return MenuBarState(
    status: status,
    detail: clock.isEmpty ? active.name : '$clock · ${active.name}',
    // Not while connecting: pressing it again does not hurry the attempt, it
    // restarts it.
    canConnect: !session.busy,
    // Available while connecting, because abandoning an attempt is a real
    // thing to want.
    canDisconnect: session.busy,
    tunnelUp: session.status == VpnStatus.connected,
    connecting: session.status == VpnStatus.connecting || profiles.switching,
  );
}
