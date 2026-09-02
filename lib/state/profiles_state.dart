import '../core/app_error.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';

/// What the app knows about its configurations: the list, which one is
/// active, what it connects through, and the two kinds of message a
/// transition can leave behind. Owned and mutated by [ProfilesController];
/// everything else reads it.
class ProfilesState {
  const ProfilesState({
    this.profiles = const [],
    this.activeId,
    this.selectedLocationId,
    this.loading = false,
    this.switching = false,
    this.error,
    this.notice,
  });

  final List<Profile> profiles;
  final String? activeId;
  final String? selectedLocationId;
  final bool loading;

  /// A hot switch is in flight: the tunnel is up and the engine is being
  /// swapped onto another location/profile. Rows ignore taps meanwhile.
  final bool switching;

  /// Blocks what the user asked for: shown as a dialog they have to dismiss.
  final AppError? error;

  /// Happened, changed nothing, needs no decision — a toast (§9 of the spec).
  /// Separate from [error] because the difference is what the user has to do
  /// about it, not how bad it sounds: a refresh that failed and a server that
  /// could not be issued both leave the previous one working, and both should
  /// read the same wherever they surface.
  final AppError? notice;

  bool get hasProfiles => profiles.isNotEmpty;

  Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  List<Location> get locations => active?.locations ?? const [];

  /// The group the selection names, when it names one. Groups and servers share
  /// the one selection the app already has: the user answers a single question
  /// — what carries my traffic — and a group is one of the answers.
  ProxyGroup? get selectedGroup {
    final id = selectedLocationId;
    if (id == null || !ProxyGroup.isGroupId(id)) return null;
    for (final g in active?.groups ?? const <ProxyGroup>[]) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// What the tunnel should carry traffic through: a group when one is chosen,
  /// otherwise a server. Every path that hands an id to the core uses this —
  /// [selectedLocation] falls back to the first server, which would silently
  /// turn a chosen group into one of its members.
  String? get selectionId => selectedGroup?.id ?? selectedLocation?.id;

  /// The servers a selected group would pick from, in the provider's order.
  List<Location> get selectedGroupMembers {
    final g = selectedGroup;
    if (g == null) return const [];
    final byId = {for (final l in locations) l.id: l};
    return [for (final id in g.members) if (byId[id] != null) byId[id]!];
  }

  Location? get selectedLocation {
    final locs = locations;
    for (final l in locs) {
      if (l.id == selectedLocationId) return l;
    }
    return locs.isEmpty ? null : locs.first;
  }

  ProfilesState copyWith({
    List<Profile>? profiles,
    String? activeId,
    String? selectedLocationId,
    bool? loading,
    bool? switching,
    AppError? error,
    AppError? notice,
  }) =>
      ProfilesState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
        selectedLocationId: selectedLocationId ?? this.selectedLocationId,
        loading: loading ?? this.loading,
        switching: switching ?? this.switching,
        error: error, // reset each transition unless passed
        notice: notice, // same: a message is for the transition that set it
      );
}
