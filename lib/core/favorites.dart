import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log.dart';

/// Pinned configurations and servers. Purely a display order: favourites come
/// first in the pickers, nothing else about them differs.
///
/// A location id is only unique inside its profile (two subscriptions can both
/// call a server "de-1"), so locations are keyed by "profileId/locationId".
class Favorites {
  const Favorites({this.profiles = const {}, this.locations = const {}});

  final Set<String> profiles;
  final Set<String> locations;

  static String locationKey(String profileId, String locationId) =>
      '$profileId/$locationId';

  bool hasProfile(String profileId) => profiles.contains(profileId);

  bool hasLocation(String profileId, String locationId) =>
      locations.contains(locationKey(profileId, locationId));

  /// The favourite location ids of one profile, as the pickers want them.
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

  /// Drop everything belonging to a removed configuration.
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
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/favorites.json');
  }

  static Future<Favorites> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const Favorites();
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return const Favorites();
      return Favorites.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      Log.e('favorites: could not load', '$e');
      return const Favorites();
    }
  }

  static Future<void> save(Favorites favorites) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(favorites.toJson()));
  }
}
