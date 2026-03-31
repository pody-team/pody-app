import 'package:shared_preferences/shared_preferences.dart';

class PlayerFavoritesStore {
  PlayerFavoritesStore._();

  static final PlayerFavoritesStore instance = PlayerFavoritesStore._();
  static const String _prefsKey = 'player_favorite_episode_ids';

  Future<bool> isFavorited(String episodeId) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = preferences.getStringList(_prefsKey) ?? const [];
    return favorites.contains(episodeId);
  }

  Future<bool> toggle(String episodeId) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites =
        preferences.getStringList(_prefsKey)?.toSet() ?? <String>{};
    final isFavorited = favorites.contains(episodeId);
    if (isFavorited) {
      favorites.remove(episodeId);
    } else {
      favorites.add(episodeId);
    }
    await preferences.setStringList(_prefsKey, favorites.toList()..sort());
    return !isFavorited;
  }

  Future<void> set(String episodeId, bool isFavorited) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites =
        preferences.getStringList(_prefsKey)?.toSet() ?? <String>{};
    if (isFavorited) {
      favorites.add(episodeId);
    } else {
      favorites.remove(episodeId);
    }
    await preferences.setStringList(_prefsKey, favorites.toList()..sort());
  }
}
