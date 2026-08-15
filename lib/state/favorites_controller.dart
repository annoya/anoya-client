import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/favorites.dart';

class FavoritesController extends Notifier<Favorites> {
  /// Completes when the persisted favourites are in [state]; mutations await
  /// it, or a toggle landing first would be overwritten when the load finishes
  /// a moment later. Already complete until [build] replaces it — a controller
  /// that never scheduled a load has nothing to wait for.
  Future<void> _ready = Future.value();

  @override
  Favorites build() {
    _ready = FavoritesStore.load().then((v) {
      state = v;
    });
    return const Favorites();
  }

  Future<void> toggleProfile(String profileId) => _save((f) => f.toggleProfile(profileId));

  Future<void> toggleLocation(String profileId, String locationId) =>
      _save((f) => f.toggleLocation(profileId, locationId));

  Future<void> forgetProfile(String profileId) => _save((f) => f.forgetProfile(profileId));

  Future<void> _save(Favorites Function(Favorites) change) async {
    await _ready;
    final favorites = change(state);
    state = favorites;
    await FavoritesStore.save(favorites);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, Favorites>(FavoritesController.new);
