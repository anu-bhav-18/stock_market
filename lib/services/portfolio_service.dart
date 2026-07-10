import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Holding {
  final String symbol;
  final String name;
  final double buyPrice;
  final double quantity;
  final DateTime buyDate;

  Holding({
    required this.symbol,
    required this.name,
    required this.buyPrice,
    required this.quantity,
    required this.buyDate,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'buyPrice': buyPrice,
    'quantity': quantity,
    'buyDate': buyDate.toIso8601String(),
  };

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
    symbol: j['symbol'] as String,
    name: j['name'] as String,
    buyPrice: (j['buyPrice'] as num).toDouble(),
    quantity: (j['quantity'] as num).toDouble(),
    buyDate: DateTime.parse(j['buyDate'] as String),
  );

  double invested() => buyPrice * quantity;
  double currentValue(double ltp) => ltp * quantity;
  double pnl(double ltp) => currentValue(ltp) - invested();
  double pnlPct(double ltp) => pnl(ltp) / invested() * 100;
}

class PortfolioService {
  static const _key = 'portfolio_holdings';

  static Future<List<Holding>> getHoldings() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.map((s) => Holding.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  static Future<void> addHolding(Holding h) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    list.add(jsonEncode(h.toJson()));
    await p.setStringList(_key, list);
  }

  static Future<void> removeHolding(int index) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await p.setStringList(_key, list);
    }
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
