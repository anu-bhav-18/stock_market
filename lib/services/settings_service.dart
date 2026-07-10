import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyGeminiKey = 'gemini_api_key';
  static const _keyApiBase   = 'api_base_url';

  static Future<String> getGeminiKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyGeminiKey) ?? '';
  }

  static Future<void> setGeminiKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyGeminiKey, key);
  }

  static Future<String> getApiBase() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyApiBase) ?? 'https://angelmod.vercel.app';
  }

  static Future<void> setApiBase(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyApiBase, url.isEmpty ? 'https://angelmod.vercel.app' : url);
  }
}
