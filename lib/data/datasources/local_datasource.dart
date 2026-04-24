import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

abstract class LocalDataSource {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
  Future<bool> containsKey(String key);
}

class SharedPreferencesDataSource implements LocalDataSource {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _instance;
    return prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _instance;
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await _instance;
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await _instance;
    await prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    final prefs = await _instance;
    return prefs.containsKey(key);
  }

  Future<void> saveJsonList(String key, List<Map<String, dynamic>> items) async {
    final jsonString = jsonEncode(items);
    await setString(key, jsonString);
  }

  Future<List<Map<String, dynamic>>> loadJsonList(String key) async {
    final jsonString = await getString(key);
    if (jsonString == null) return [];
    final decoded = jsonDecode(jsonString);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
