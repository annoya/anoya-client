import 'json_file_store.dart';

class Favorites {
  const Favorites({this.profiles = const {}, this.locations = const {}});

  final Set<String> profiles;
  final Set<String> locations;

  static String locationKey(String profileId, String locationId) =>
      '$profileId/$locationId';

  Set<String> locationsOf(String profileId) {
    final prefix = '$profileId/';
    return {
      for (final key in locations)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    };
  }

  Favorites toggleProfile(String profileId) => Favorites(
    profiles: {...profiles}..toggle(profileId),
    locations: locations,
  );

  Favorites toggleLocation(String profileId, String locationId) => Favorites(
    profiles: profiles,
    locations: {...locations}..toggle(locationKey(profileId, locationId)),
  );

  Favorites forgetProfile(String profileId) => Favorites(
    profiles: {...profiles}..remove(profileId),
    locations: {
      for (final key in locations)
        if (!key.startsWith('$profileId/')) key,
    },
  );

  factory Favorites.fromJson(Map<String, dynamic> j) => Favorites(
    profiles: (j['profiles'] as List<dynamic>? ?? []).cast<String>().toSet(),
    locations: (j['locations'] as List<dynamic>? ?? []).cast<String>().toSet(),
  );

  Map<String, dynamic> toJson() => {
    'profiles': profiles.toList(),
    'locations': locations.toList(),
  };
}

extension on Set<String> {
  void toggle(String value) => contains(value) ? remove(value) : add(value);
}

class FavoritesStore {
  static final _store = JsonFileStore('favorites.json');

  static Future<Favorites> load() => _store.load(
    (j) => j is Map
        ? Favorites.fromJson(Map<String, dynamic>.from(j))
        : const Favorites(),
    const Favorites(),
  );

  static Future<void> save(Favorites favorites) =>
      _store.save(favorites.toJson());
}
