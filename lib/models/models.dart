class StockIndex {
  final String name;
  final int count;
  const StockIndex({required this.name, required this.count});
  factory StockIndex.fromJson(Map<String, dynamic> j) =>
      StockIndex(name: j['name'] as String, count: (j['count'] as num).toInt());
}

class Stock {
  final String symbol;
  final String name;
  const Stock({required this.symbol, required this.name});
  factory Stock.fromJson(Map<String, dynamic> j) =>
      Stock(symbol: j['symbol'] as String, name: j['name'] as String);
}

class Quote {
  final double price;
  final double prevClose;
  final double change;
  final double changePct;
  const Quote({required this.price, required this.prevClose, required this.change, required this.changePct});
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        price: (j['price'] as num).toDouble(),
        prevClose: (j['prev_close'] as num).toDouble(),
        change: (j['change'] as num).toDouble(),
        changePct: (j['change_pct'] as num).toDouble(),
      );
}

class HistoryPoint {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? sma20;
  final double? sma50;
  final double? rsi14;
  final double? macd;
  final double? bbUpper;
  final double? bbLower;
  const HistoryPoint({
    required this.date, required this.open, required this.high,
    required this.low, required this.close,
    this.sma20, this.sma50, this.rsi14, this.macd, this.bbUpper, this.bbLower,
  });
  factory HistoryPoint.fromJson(Map<String, dynamic> j) => HistoryPoint(
        date: j['Date'] as String,
        open: (j['Open'] as num).toDouble(),
        high: (j['High'] as num).toDouble(),
        low: (j['Low'] as num).toDouble(),
        close: (j['Close'] as num).toDouble(),
        sma20: j['SMA_20'] != null ? (j['SMA_20'] as num).toDouble() : null,
        sma50: j['SMA_50'] != null ? (j['SMA_50'] as num).toDouble() : null,
        rsi14: j['RSI_14'] != null ? (j['RSI_14'] as num).toDouble() : null,
        macd: j['MACD'] != null ? (j['MACD'] as num).toDouble() : null,
        bbUpper: j['BB_upper'] != null ? (j['BB_upper'] as num).toDouble() : null,
        bbLower: j['BB_lower'] != null ? (j['BB_lower'] as num).toDouble() : null,
      );
}

class TechnicalSignal {
  final int score;
  final String label;
  final List<String> reasons;
  const TechnicalSignal({required this.score, required this.label, required this.reasons});
  factory TechnicalSignal.fromJson(Map<String, dynamic> j) => TechnicalSignal(
        score: (j['score'] as num).toInt(),
        label: j['label'] as String,
        reasons: List<String>.from(j['reasons'] as List),
      );
}

class MLSignal {
  final bool available;
  final double? probabilityUp;
  final int? horizonDays;
  final double? backtestAccuracy;
  final String? reason;
  const MLSignal({required this.available, this.probabilityUp, this.horizonDays, this.backtestAccuracy, this.reason});
  factory MLSignal.fromJson(Map<String, dynamic> j) => MLSignal(
        available: j['available'] as bool,
        probabilityUp: j['probability_up'] != null ? (j['probability_up'] as num).toDouble() : null,
        horizonDays: j['horizon_days'] != null ? (j['horizon_days'] as num).toInt() : null,
        backtestAccuracy: j['backtest_accuracy'] != null ? (j['backtest_accuracy'] as num).toDouble() : null,
        reason: j['reason'] as String?,
      );
}

class SignalResult {
  final double compositeScore;
  final TechnicalSignal technical;
  final MLSignal ml;
  const SignalResult({required this.compositeScore, required this.technical, required this.ml});
  factory SignalResult.fromJson(Map<String, dynamic> j) => SignalResult(
        compositeScore: (j['composite_score'] as num).toDouble(),
        technical: TechnicalSignal.fromJson(j['technical'] as Map<String, dynamic>),
        ml: MLSignal.fromJson(j['ml'] as Map<String, dynamic>),
      );
}

class MoverStock {
  final String symbol;
  final String fullSymbol;
  final String name;
  final double price;
  final double dayChangePct;
  final double compositeScore;
  final String technicalLabel;
  final double? mlProbUp;
  const MoverStock({
    required this.symbol, required this.fullSymbol, required this.name,
    required this.price, required this.dayChangePct,
    required this.compositeScore, required this.technicalLabel, this.mlProbUp,
  });
  factory MoverStock.fromJson(Map<String, dynamic> j) => MoverStock(
        symbol: j['symbol'] as String,
        fullSymbol: j['full_symbol'] as String? ?? '${j['symbol']}.NS',
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        dayChangePct: (j['day_change_pct'] as num).toDouble(),
        compositeScore: (j['composite_score'] as num).toDouble(),
        technicalLabel: j['technical_label'] as String,
        mlProbUp: j['ml_prob_up'] != null ? (j['ml_prob_up'] as num).toDouble() : null,
      );
}

class ReturnResult {
  final double startPrice;
  final double endPrice;
  final double pctReturn;
  final double cagr;
  final double annualizedVolatility;
  final int days;
  const ReturnResult({
    required this.startPrice, required this.endPrice, required this.pctReturn,
    required this.cagr, required this.annualizedVolatility, required this.days,
  });
  factory ReturnResult.fromJson(Map<String, dynamic> j) => ReturnResult(
        startPrice: (j['start_price'] as num).toDouble(),
        endPrice: (j['end_price'] as num).toDouble(),
        pctReturn: (j['pct_return'] as num).toDouble(),
        cagr: (j['cagr'] as num).toDouble(),
        annualizedVolatility: (j['annualized_volatility'] as num).toDouble(),
        days: (j['days'] as num).toInt(),
      );
}

// ── F&O models ────────────────────────────────────────────────────────────────

class StrikeData {
  final double strike;
  final int ceOI;
  final int ceCOI;
  final int ceVolume;
  final double ceIV;
  final double ceLTP;
  final int peOI;
  final int peCOI;
  final int peVolume;
  final double peIV;
  final double peLTP;

  const StrikeData({
    required this.strike,
    required this.ceOI, required this.ceCOI, required this.ceVolume,
    required this.ceIV, required this.ceLTP,
    required this.peOI, required this.peCOI, required this.peVolume,
    required this.peIV, required this.peLTP,
  });

  factory StrikeData.fromJson(Map<String, dynamic> j) => StrikeData(
        strike: (j['strike'] as num).toDouble(),
        ceOI: (j['ce_oi'] as num).toInt(),
        ceCOI: (j['ce_coi'] as num).toInt(),
        ceVolume: (j['ce_volume'] as num).toInt(),
        ceIV: (j['ce_iv'] as num).toDouble(),
        ceLTP: (j['ce_ltp'] as num).toDouble(),
        peOI: (j['pe_oi'] as num).toInt(),
        peCOI: (j['pe_coi'] as num).toInt(),
        peVolume: (j['pe_volume'] as num).toInt(),
        peIV: (j['pe_iv'] as num).toDouble(),
        peLTP: (j['pe_ltp'] as num).toDouble(),
      );
}

class OptionsChain {
  final double spot;
  final String selectedExpiry;
  final List<String> allExpiries;
  final double pcr;
  final String pcrSignal;
  final double maxPain;
  final String direction;
  final List<String> reasoning;
  final String oiBias;
  final int totalCeOI;
  final int totalPeOI;
  final double atmCeLtp;
  final double atmPeLtp;
  final double atmCeIv;
  final double atmPeIv;
  final List<StrikeData> strikes;

  const OptionsChain({
    required this.spot, required this.selectedExpiry, required this.allExpiries,
    required this.pcr, required this.pcrSignal, required this.maxPain,
    required this.direction, required this.reasoning, required this.oiBias,
    required this.totalCeOI, required this.totalPeOI,
    required this.atmCeLtp, required this.atmPeLtp,
    required this.atmCeIv, required this.atmPeIv,
    required this.strikes,
  });

  factory OptionsChain.fromJson(Map<String, dynamic> j) => OptionsChain(
        spot: (j['spot'] as num).toDouble(),
        selectedExpiry: j['selected_expiry'] as String? ?? '',
        allExpiries: List<String>.from(j['all_expiries'] as List? ?? []),
        pcr: (j['pcr'] as num).toDouble(),
        pcrSignal: j['pcr_signal'] as String,
        maxPain: (j['max_pain'] as num).toDouble(),
        direction: j['direction'] as String,
        reasoning: List<String>.from(j['reasoning'] as List? ?? []),
        oiBias: j['oi_bias'] as String? ?? '',
        totalCeOI: (j['total_ce_oi'] as num).toInt(),
        totalPeOI: (j['total_pe_oi'] as num).toInt(),
        atmCeLtp: (j['atm_ce_ltp'] as num? ?? 0).toDouble(),
        atmPeLtp: (j['atm_pe_ltp'] as num? ?? 0).toDouble(),
        atmCeIv: (j['atm_ce_iv'] as num? ?? 0).toDouble(),
        atmPeIv: (j['atm_pe_iv'] as num? ?? 0).toDouble(),
        strikes: (j['strikes'] as List)
            .map((e) => StrikeData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  double get atmStrike {
    if (strikes.isEmpty) return spot;
    return strikes.reduce((a, b) =>
        (a.strike - spot).abs() < (b.strike - spot).abs() ? a : b).strike;
  }
}
