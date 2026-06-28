import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // ── Change this to your Vercel URL once deployed ──────────────────────────
  // Production:  'https://your-project.vercel.app'
  // Emulator:    'http://10.0.2.2:8000'
  // Physical dev: 'http://192.168.x.x:8000'
  // ──────────────────────────────────────────────────────────────────────────
  static const String base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final uri = Uri.parse('$base$path');
    final res = await http.get(uri).timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('${res.statusCode} ${res.body}');
    }
    return parse(jsonDecode(res.body));
  }

  static Future<List<Stock>> fetchStocks() => _get(
        '/stocks',
        (d) => (d as List).map((e) => Stock.fromJson(e as Map<String, dynamic>)).toList(),
      );

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

  static Future<List<MoverStock>> fetchScreener({int horizon = 5}) => _get(
        '/screener?horizon=$horizon',
        (d) => (d as List).map((e) => MoverStock.fromJson(e as Map<String, dynamic>)).toList(),
      );

  static Future<ReturnResult> fetchReturn(String symbol, String start, String end) => _get(
        '/return/$symbol?start=$start&end=$end',
        (d) => ReturnResult.fromJson(d as Map<String, dynamic>),
      );
}
