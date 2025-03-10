import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _kVTRNameKey = 'vtr_name';

  static Future<void> saveVTRName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVTRNameKey, name);
  }

  static Future<String?> getVTRName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kVTRNameKey);
  }
}