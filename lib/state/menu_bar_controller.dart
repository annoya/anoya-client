import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/menu_bar.dart';
import '../core/profile.dart';
import '../core/vpn_core.dart';
import '../l10n/l10n.dart';
import 'profiles_controller.dart';
import 'session.dart';

final menuBarProvider = Provider<MenuBar>((ref) {
  final menu = MenuBar();
  if (!MenuBar.supported) return menu;

  final profiles = ref.read(profilesControllerProvider.notifier);
  menu.onConnect = profiles.connect;
  menu.onDisconnect = profiles.disconnect;
  menu.onSync = () => _push(ref, menu);
  menu.start();

  ref.listen(
    sessionProvider,
    (_, _) => _push(ref, menu),
    fireImmediately: true,
  );
  ref.listen(profilesControllerProvider, (_, _) => _push(ref, menu));
  ref.onDispose(menu.dispose);
  return menu;
});

void _push(Ref ref, MenuBar menu) => menu.update(
  menuBarStateFor(
    ref.read(sessionProvider),
    ref.read(profilesControllerProvider),
  ),
);

MenuBarState menuBarStateFor(SessionState session, ProfilesState profiles) {
  final l10n = L10n.current;
  final Profile? active = profiles.active;
  final location = profiles.selectedLocation;

  if (active == null) {
    return MenuBarState(status: l10n.statusNoConfiguration);
  }

  final where = location == null ? '' : ' · ${location.label}';
  final clock = sessionClock(session.startedAt);
  final status = switch (session.status) {
    _ when profiles.switching => '${l10n.menuBarSwitching}$where',
    VpnStatus.connected => '${l10n.statusConnected}$where',
    VpnStatus.connecting => '${l10n.statusConnecting}$where',
    VpnStatus.error => l10n.statusError,
    VpnStatus.disconnected => l10n.statusNotConnected,
  };

  return MenuBarState(
    status: status,
    detail: clock.isEmpty ? active.name : '$clock · ${active.name}',
    canConnect: !session.busy,
    canDisconnect: session.busy,
    tunnelUp: session.status == VpnStatus.connected,
    connecting: session.status == VpnStatus.connecting || profiles.switching,
  );
}
