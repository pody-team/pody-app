import 'package:flutter_test/flutter_test.dart';
import 'package:pody/screens/show/player_favorites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('toggle persists favorite episode ids across reads', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlayerFavoritesStore.instance;

    expect(await store.isFavorited('episode-1'), isFalse);

    expect(await store.toggle('episode-1'), isTrue);
    expect(await store.isFavorited('episode-1'), isTrue);

    expect(await store.toggle('episode-1'), isFalse);
    expect(await store.isFavorited('episode-1'), isFalse);
  });
}
