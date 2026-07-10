import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TradeStatus { open, closed }
enum TradeSide { buy, sell }

class TradeEntry {
  final String id;
  final String symbol;
  final String name;
  final TradeSide side;
  final double entryPrice;
  final int qty;
  final double? stopLoss;
  final double? target;
  final String notes;
  final DateTime entryDate;
  double? exitPrice;
  DateTime? exitDate;
  TradeStatus status;

  TradeEntry({
    required this.id,
    required this.symbol,
    required this.name,
    required this.side,
    required this.entryPrice,
    required this.qty,
    this.stopLoss,
    this.target,
    this.notes = '',
    required this.entryDate,
    this.exitPrice,
    this.exitDate,
    this.status = TradeStatus.open,
  });

  double get invested => entryPrice * qty;
  double get riskAmount => stopLoss != null ? (entryPrice - stopLoss!).abs() * qty : 0;
  double get rewardAmount => target != null ? (target! - entryPrice).abs() * qty : 0;
  double get rrRatio => riskAmount > 0 ? rewardAmount / riskAmount : 0;

  double pnl(double ltp) {
    final exit = exitPrice ?? ltp;
    return side == TradeSide.buy
        ? (exit - entryPrice) * qty
        : (entryPrice - exit) * qty;
  }

  double pnlPct(double ltp) {
    return invested > 0 ? pnl(ltp) / invested * 100 : 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'name': name,
    'side': side.name,
    'entry_price': entryPrice,
    'qty': qty,
    'stop_loss': stopLoss,
    'target': target,
    'notes': notes,
    'entry_date': entryDate.toIso8601String(),
    'exit_price': exitPrice,
    'exit_date': exitDate?.toIso8601String(),
    'status': status.name,
  };

  factory TradeEntry.fromJson(Map<String, dynamic> j) => TradeEntry(
    id: j['id'] as String,
    symbol: j['symbol'] as String,
    name: j['name'] as String? ?? j['symbol'] as String,
    side: j['side'] == 'sell' ? TradeSide.sell : TradeSide.buy,
    entryPrice: (j['entry_price'] as num).toDouble(),
    qty: (j['qty'] as num).toInt(),
    stopLoss: j['stop_loss'] != null ? (j['stop_loss'] as num).toDouble() : null,
    target: j['target'] != null ? (j['target'] as num).toDouble() : null,
    notes: j['notes'] as String? ?? '',
    entryDate: DateTime.parse(j['entry_date'] as String),
    exitPrice: j['exit_price'] != null ? (j['exit_price'] as num).toDouble() : null,
    exitDate: j['exit_date'] != null ? DateTime.parse(j['exit_date'] as String) : null,
    status: j['status'] == 'closed' ? TradeStatus.closed : TradeStatus.open,
  );
}

class PlannerService {
  static const _key = 'trade_planner';

  static Future<List<TradeEntry>> getTrades() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => TradeEntry.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  static Future<void> addTrade(TradeEntry t) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(t.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> updateTrade(TradeEntry updated) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final idx = raw.indexWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == updated.id;
    });
    if (idx >= 0) raw[idx] = jsonEncode(updated.toJson());
    await prefs.setStringList(_key, raw);
  }

  static Future<void> removeTrade(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }
}
