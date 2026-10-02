import '../core/app_error.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';

class ProfilesState {
  const ProfilesState({
    this.profiles = const [],
    this.activeId,
    this.selectedLocationId,
    this.loading = false,
    this.switching = false,
    this.preparing = false,
    this.error,
    this.notice,
  });

  final List<Profile> profiles;
  final String? activeId;
  final String? selectedLocationId;
  final bool loading;

  final bool switching;

  final bool preparing;

  final AppError? error;

  final AppError? notice;

  bool get hasProfiles => profiles.isNotEmpty;

  Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  List<Location> get locations => active?.locations ?? const [];

  ProxyGroup? get selectedGroup {
    final id = selectedLocationId;
    if (id == null || !ProxyGroup.isGroupId(id)) return null;
    for (final g in active?.groups ?? const <ProxyGroup>[]) {
      if (g.id == id) return g;
    }
    return null;
  }

  String? get selectionId => selectedGroup?.id ?? selectedLocation?.id;

  List<Location> get selectedGroupMembers {
    final g = selectedGroup;
    if (g == null) return const [];
    final byId = {for (final l in locations) l.id: l};
    return [
      for (final id in g.members)
        if (byId[id] != null) byId[id]!,
    ];
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
    bool? preparing,
    AppError? error,
    AppError? notice,
  }) => ProfilesState(
    profiles: profiles ?? this.profiles,
    activeId: activeId ?? this.activeId,
    selectedLocationId: selectedLocationId ?? this.selectedLocationId,
    loading: loading ?? this.loading,
    switching: switching ?? this.switching,
    preparing: preparing ?? this.preparing,
    error: error,
    notice: notice,
  );
}
