import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PriceAlert {
  final String symbol;
  final String name;
  final double targetPrice;
  final bool isAbove; // true = alert when price >= target, false = when price <= target

  PriceAlert({
    required this.symbol,
    required this.name,
    required this.targetPrice,
    required this.isAbove,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'targetPrice': targetPrice,
    'isAbove': isAbove,
  };

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
    symbol: j['symbol'] as String,
    name: j['name'] as String,
    targetPrice: (j['targetPrice'] as num).toDouble(),
    isAbove: j['isAbove'] as bool,
  );

  String get label => isAbove ? 'above ₹${targetPrice.toStringAsFixed(2)}' : 'below ₹${targetPrice.toStringAsFixed(2)}';
}

class AlertService {
  static const _key = 'price_alerts';
  static final _notif = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  static Future<List<PriceAlert>> getAlerts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.map((s) => PriceAlert.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  static Future<void> addAlert(PriceAlert alert) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    list.add(jsonEncode(alert.toJson()));
    await p.setStringList(_key, list);
  }

  static Future<void> removeAlert(int index) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await p.setStringList(_key, list);
    }
  }

  static Future<void> checkAlerts(Map<String, double> prices) async {
    await init();
    final alerts = await getAlerts();
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    final toRemove = <int>[];

    for (int i = 0; i < alerts.length; i++) {
      final a = alerts[i];
      final price = prices[a.symbol];
      if (price == null) continue;
      final triggered = a.isAbove ? price >= a.targetPrice : price <= a.targetPrice;
      if (triggered) {
        await _notif.show(
          i,
          'Price Alert: ${a.symbol}',
          '${a.symbol} is now ₹${price.toStringAsFixed(2)} (${a.label})',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'price_alerts', 'Price Alerts',
              channelDescription: 'Stock price alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        toRemove.add(i);
      }
    }

    for (final i in toRemove.reversed) {
      list.removeAt(i);
    }
    await p.setStringList(_key, list);
  }
}
