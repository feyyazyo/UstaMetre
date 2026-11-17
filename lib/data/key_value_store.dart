import 'package:shared_preferences/shared_preferences.dart';

/// Cihaz içi (offline) anahtar-değer deposu. Uygulama verisi internete
/// gönderilmez.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Android'de SharedPreferences ile kalıcı depolama.
final class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesStore> open() async =>
      SharedPreferencesStore(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }
}

/// Bellek içi depo (testler ve kalıcılık gerektirmeyen önizlemeler için).
final class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
