import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://stock-market-sandy-theta.vercel.app',
  );

  static Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final res = await http
        .get(Uri.parse('$base$path'))
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw Exception('${res.statusCode}: $path');
    return parse(jsonDecode(res.body));
  }

  // ── Indices & stocks ───────────────────────────────────────────────────────

  static Future<List<StockIndex>> fetchIndices() => _get(
        '/indices',
        (d) => (d as List).map((e) => StockIndex.fromJson(e as Map<String, dynamic>)).toList(),
      );

  static Future<List<Stock>> fetchStocks({String index = 'Nifty 50'}) => _get(
        '/stocks?index=${Uri.encodeComponent(index)}',
        (d) => (d as List).map((e) => Stock.fromJson(e as Map<String, dynamic>)).toList(),
      );

  // ── Market data ────────────────────────────────────────────────────────────

  static Future<Quote> fetchQuote(String symbol) => _get(
        '/quote/$symbol',
        (d) => Quote.fromJson(d as Map<String, dynamic>),
      );

  static Future<List<HistoryPoint>> fetchHistory(String symbol, {String period = '6mo'}) => _get(
        '/history/$symbol?period=$period',
        (d) => (d as List).map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );

  static Future<SignalResult> fetchSignal(String symbol, {int horizon = 5}) => _get(
        '/signal/$symbol?horizon=$horizon',
        (d) => SignalResult.fromJson(d as Map<String, dynamic>),
      );

  static Future<List<MoverStock>> fetchScreener({String index = 'Nifty 50', int horizon = 5}) => _get(
        '/screener?index=${Uri.encodeComponent(index)}&horizon=$horizon',
        (d) => (d as List).map((e) => MoverStock.fromJson(e as Map<String, dynamic>)).toList(),
      );

  static Future<ReturnResult> fetchReturn(String symbol, String start, String end) => _get(
        '/return/$symbol?start=$start&end=$end',
        (d) => ReturnResult.fromJson(d as Map<String, dynamic>),
      );

  // ── Levels & Patterns ──────────────────────────────────────────────────────

  static Future<Levels> fetchLevels(String symbol) => _get(
        '/levels/$symbol',
        (d) => Levels.fromJson(d as Map<String, dynamic>),
      );

  static Future<List<CandlePattern>> fetchPatterns(String symbol) => _get(
        '/patterns/$symbol',
        (d) => (d['patterns'] as List)
            .map((e) => CandlePattern.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  // ── Intraday ───────────────────────────────────────────────────────────────

  static Future<List<IntradayStock>> fetchIntradayScan({
    String index = 'Nifty Bank',
    String interval = '15m',
  }) =>
      _get(
        '/intraday/scan?index=${Uri.encodeComponent(index)}&interval=$interval',
        (d) => (d as List).map((e) => IntradayStock.fromJson(e as Map<String, dynamic>)).toList(),
      );

  // ── F&O ───────────────────────────────────────────────────────────────────

  static Future<OptionsChain> fetchOptionsChain(String symbol, {String? expiry}) {
    final q = expiry != null ? '?expiry=${Uri.encodeComponent(expiry)}' : '';
    return _get(
      '/fno/chain/$symbol$q',
      (d) => OptionsChain.fromJson(d as Map<String, dynamic>),
    );
  }
}
