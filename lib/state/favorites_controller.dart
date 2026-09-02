import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/favorites.dart';
import 'ready_gate.dart';

class FavoritesController extends Notifier<Favorites> with ReadyGate {
  @override
  Favorites build() {
    ready = FavoritesStore.load().then((v) {
      state = v;
    });
    return const Favorites();
  }

  Future<void> toggleProfile(String profileId) => _save((f) => f.toggleProfile(profileId));

  Future<void> toggleLocation(String profileId, String locationId) =>
      _save((f) => f.toggleLocation(profileId, locationId));

  Future<void> forgetProfile(String profileId) => _save((f) => f.forgetProfile(profileId));

  Future<void> _save(Favorites Function(Favorites) change) async {
    await ready;
    final favorites = change(state);
    state = favorites;
    await FavoritesStore.save(favorites);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, Favorites>(FavoritesController.new);
