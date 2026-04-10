import 'package:shared_preferences/shared_preferences.dart';

/// 简单键值存储（字符串），供 WebView JS 通过桥调用。
class StorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getString(String key) async => (await _prefs).getString(key);

  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }

  Future<void> clear() async {
    await (await _prefs).clear();
  }

  Future<List<String>> getKeys() async {
    return (await _prefs).getKeys().toList();
  }
}
