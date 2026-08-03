import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/favorites.dart';

class FavoritesController extends Notifier<Favorites> {
  @override
  Favorites build() {
    Future.microtask(() async => state = await FavoritesStore.load());
    return const Favorites();
  }

  Future<void> toggleProfile(String profileId) => _save(state.toggleProfile(profileId));

  Future<void> toggleLocation(String profileId, String locationId) =>
      _save(state.toggleLocation(profileId, locationId));

  Future<void> forgetProfile(String profileId) => _save(state.forgetProfile(profileId));

  Future<void> _save(Favorites favorites) async {
    state = favorites;
    await FavoritesStore.save(favorites);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, Favorites>(FavoritesController.new);
