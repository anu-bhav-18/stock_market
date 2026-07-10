import 'package:shared_preferences/shared_preferences.dart';

class WatchlistService {
  static const _key = 'watchlist_v1';

  static Future<List<String>> getSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<bool> isWatched(String symbol) async {
    final list = await getSymbols();
    return list.contains(symbol);
  }

  static Future<void> add(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (!list.contains(symbol)) {
      list.add(symbol);
      await prefs.setStringList(_key, list);
    }
  }

  static Future<void> remove(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(symbol);
    await prefs.setStringList(_key, list);
  }

  static Future<void> toggle(String symbol) async {
    if (await isWatched(symbol)) {
      await remove(symbol);
    } else {
      await add(symbol);
    }
  }
}
