import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/alert_service.dart';
import '../services/watchlist_service.dart';
import '../services/gemini_service.dart';
import '../theme.dart';
import '../widgets/stock_chart.dart';
import 'ai_chat_screen.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  final String name;
  const StockDetailScreen({super.key, required this.symbol, required this.name});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  Quote? _quote;
  List<HistoryPoint> _history = [];
  SignalResult? _signal;
  Levels? _levels;
  List<NewsItem> _news = [];
  bool _loading = true;
  String? _error;
  bool _watched = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    Quote? quote;
    List<HistoryPoint> history = [];
    SignalResult? signal;
    Levels? levels;
    List<NewsItem> news = [];
    bool watched = false;

    await Future.wait([
      ApiService.fetchQuote(widget.symbol).then((v) { quote = v; }).catchError((_) {}),
      ApiService.fetchHistory(widget.symbol, period: '6mo').then((v) { history = v; }).catchError((_) {}),
      ApiService.fetchSignal(widget.symbol).then((v) { signal = v; }).catchError((_) {}),
      ApiService.fetchLevels(widget.symbol).then((v) { levels = v; }).catchError((_) {}),
      WatchlistService.isWatched(widget.symbol).then((v) { watched = v; }).catchError((_) {}),
      ApiService.fetchNews(widget.symbol).then((v) { news = v; }).catchError((_) {}),
    ]);

    if (quote == null && history.isEmpty) {
      if (mounted) setState(() { _error = 'Could not load data for ${widget.symbol}'; _loading = false; });
      return;
    }

    if (mounted) {
      setState(() {
        _quote = quote;
        _history = history;
        _signal = signal;
        _levels = levels;
        _news = news;
        _watched = watched;
        _loading = false;
      });
    }
  }

  Future<void> _toggleWatch() async {
    await WatchlistService.toggle(widget.symbol);
    final w = await WatchlistService.isWatched(widget.symbol);
    if (mounted) setState(() => _watched = w);
  }

  Future<void> _showAlertDialog() async {
    final price = _quote?.price ?? 0;
    final ctrl  = TextEditingController(text: price.toStringAsFixed(2));
    bool isAbove = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Price Alert: ${widget.symbol.replaceAll('.NS', '')}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Current: ₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Price (₹)'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Alert when price is'),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Above'), selected: isAbove,
                  onSelected: (_) => setSt(() => isAbove = true),
                  selectedColor: AppTheme.green.withValues(alpha: 0.2)),
              const SizedBox(width: 6),
              ChoiceChip(label: const Text('Below'), selected: !isAbove,
                  onSelected: (_) => setSt(() => isAbove = false),
                  selectedColor: AppTheme.red.withValues(alpha: 0.2)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final target = double.tryParse(ctrl.text.trim()) ?? 0;
                if (target <= 0) return;
                final messenger = ScaffoldMessenger.of(context);
                await AlertService.addAlert(PriceAlert(
                  symbol: widget.symbol, name: widget.name,
                  targetPrice: target, isAbove: isAbove,
                ));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Alert set: ${isAbove ? 'above' : 'below'} ₹${target.toStringAsFixed(2)}'),
                        backgroundColor: AppTheme.green),
                  );
                }
              },
              child: const Text('Set Alert'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _analyzeWithAI() async {
    final ready = await GeminiService.init();
    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Set your Gemini API key in Settings first'),
        backgroundColor: AppTheme.red,
      ));
      return;
    }
    final s = _signal;
    final q = _quote;
    final response = await GeminiService.analyzeStock(
      symbol: widget.symbol.replaceAll('.NS', ''),
      name: widget.name,
      price: q?.price ?? 0,
      changePct: q?.changePct ?? 0,
      signal: s?.technical.label ?? 'N/A',
      score: s?.compositeScore ?? 0,
      mlProb: s?.ml.probabilityUp,
      reasons: s?.technical.reasons ?? [],
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AiChatScreen(initialMessage: response),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symbol.replaceAll('.NS', ''),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(widget.name, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Set Price Alert',
            onPressed: _showAlertDialog,
          ),
          IconButton(
            icon: Icon(_watched ? Icons.star_rounded : Icons.star_border_rounded,
                color: _watched ? Colors.amber : null),
            onPressed: _toggleWatch,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.green),
                SizedBox(height: 12),
                Text('Fetching live data...', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _DetailBody(
                  symbol: widget.symbol,
                  name: widget.name,
                  quote: _quote,
                  history: _history,
                  signal: _signal,
                  levels: _levels,
                  news: _news,
                  onAnalyzeAI: _analyzeWithAI,
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('Failed to load data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final String symbol;
  final String name;
  final Quote? quote;
  final List<HistoryPoint> history;
  final SignalResult? signal;
  final Levels? levels;
  final List<NewsItem> news;
  final VoidCallback onAnalyzeAI;
  const _DetailBody({
    required this.symbol, required this.name, required this.quote,
    required this.history, required this.signal, required this.levels,
    required this.news, required this.onAnalyzeAI,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (quote != null) ...[
          _PriceCard(quote: quote!),
          const SizedBox(height: 12),
        ],
        if (signal != null) ...[
          _RecommendationCard(signal: signal!),
          const SizedBox(height: 12),
        ],
        // AI Analyze button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAnalyzeAI,
            icon: const Icon(Icons.psychology_rounded, size: 18),
            label: const Text('Analyze with AI'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.blue,
              side: const BorderSide(color: AppTheme.blue),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (history.isNotEmpty) ...[
          _ChartCard(history: history),
          const SizedBox(height: 12),
        ],
        if (signal != null && history.isNotEmpty) ...[
          _IndicatorsCard(history: history, quote: quote),
          const SizedBox(height: 12),
        ],
        if (signal != null) ...[
          _SignalsCard(signal: signal!),
          const SizedBox(height: 12),
          if (signal!.ml.available) ...[
            _MLCard(ml: signal!.ml),
            const SizedBox(height: 12),
          ],
          if (signal!.patterns.isNotEmpty) ...[
            _PatternsCard(patterns: signal!.patterns),
            const SizedBox(height: 12),
          ],
        ],
        if (levels != null) ...[
          _LevelsCard(levels: levels!, price: quote?.price ?? 0),
          const SizedBox(height: 12),
        ],
        if (news.isNotEmpty) ...[
          _NewsCard(news: news),
          const SizedBox(height: 12),
        ],
        const Text(
          '⚠ For educational use only. Not financial advice.',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Price header ──────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final Quote quote;
  const _PriceCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final isUp = q.changePct >= 0;
    final color = isUp ? AppTheme.green : AppTheme.red;
    final volLabel = 'N/A';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${q.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                      Row(children: [
                        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: color),
                        Text(
                          '${isUp ? '+' : ''}${q.changePct.toStringAsFixed(2)}%  '
                          '(${isUp ? '+' : ''}₹${q.change.toStringAsFixed(2)})',
                          style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Prev Close', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  Text('₹${q.prevClose.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Volume', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  Text(volLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recommendation card ───────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final SignalResult signal;
  const _RecommendationCard({required this.signal});

  Color get _color {
    final label = signal.technical.label;
    if (label.contains('Strong Buy')) return AppTheme.green;
    if (label.contains('Buy')) return const Color(0xFF4CAF50);
    if (label.contains('Strong Sell')) return AppTheme.red;
    if (label.contains('Sell')) return const Color(0xFFE57373);
    return Colors.orange;
  }

  IconData get _icon {
    final label = signal.technical.label;
    if (label.contains('Buy')) return Icons.trending_up_rounded;
    if (label.contains('Sell')) return Icons.trending_down_rounded;
    return Icons.remove_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final score = signal.compositeScore;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommendation', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text(signal.technical.label,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _color)),
                    ],
                  ),
                ),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(score.toStringAsFixed(0),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _color)),
                    Text('/100', style: TextStyle(fontSize: 9, color: _color.withValues(alpha: 0.7))),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Score bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Strong Sell', style: TextStyle(fontSize: 9, color: AppTheme.red)),
                Text('Score: ${score.toStringAsFixed(0)}/100',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                const Text('Strong Buy', style: TextStyle(fontSize: 9, color: AppTheme.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<HistoryPoint> history;
  const _ChartCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price Chart (6M)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            StockChart(data: history),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppTheme.green, label: 'Close'),
                SizedBox(width: 14),
                _LegendDot(color: AppTheme.blue, label: 'SMA 20'),
                SizedBox(width: 14),
                _LegendDot(color: AppTheme.red, label: 'SMA 50'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]);
}

// ── Technical indicators ──────────────────────────────────────────────────────

class _IndicatorsCard extends StatelessWidget {
  final List<HistoryPoint> history;
  final Quote? quote;
  const _IndicatorsCard({required this.history, required this.quote});

  @override
  Widget build(BuildContext context) {
    final last = history.isNotEmpty ? history.last : null;
    final price = quote?.price ?? last?.close ?? 0.0;
    final rsi = last?.rsi14 ?? 50.0;
    final macd = last?.macd ?? 0.0;
    final sma20 = last?.sma20 ?? 0.0;
    final sma50 = last?.sma50 ?? 0.0;
    final bbUpper = last?.bbUpper ?? 0.0;
    final bbLower = last?.bbLower ?? 0.0;
    final bbRange = bbUpper - bbLower;
    final bbPct = bbRange > 0 ? ((price - bbLower) / bbRange * 100).clamp(0.0, 100.0) : 50.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Technical Indicators', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _IndicatorTile(
                label: 'RSI (14)',
                value: rsi.toStringAsFixed(1),
                subtext: rsi > 70 ? 'Overbought' : rsi < 30 ? 'Oversold' : 'Neutral',
                color: rsi > 70 ? AppTheme.red : rsi < 30 ? AppTheme.green : Colors.orange,
                barValue: rsi / 100,
                barColor: rsi > 70 ? AppTheme.red : rsi < 30 ? AppTheme.green : Colors.orange,
              )),
              const SizedBox(width: 10),
              Expanded(child: _IndicatorTile(
                label: 'MACD',
                value: macd.toStringAsFixed(2),
                subtext: macd > 0 ? 'Bullish' : 'Bearish',
                color: macd > 0 ? AppTheme.green : AppTheme.red,
                barValue: null,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _IndicatorTile(
                label: 'SMA 20 / 50',
                value: '${sma20.toStringAsFixed(0)} / ${sma50.toStringAsFixed(0)}',
                subtext: price > sma20 && price > sma50
                    ? 'Above both (Bullish)'
                    : price < sma20 && price < sma50
                        ? 'Below both (Bearish)'
                        : 'Mixed',
                color: price > sma20 && price > sma50
                    ? AppTheme.green
                    : price < sma20 && price < sma50
                        ? AppTheme.red
                        : Colors.orange,
                barValue: null,
              )),
              const SizedBox(width: 10),
              Expanded(child: _IndicatorTile(
                label: 'Bollinger %B',
                value: '${bbPct.toStringAsFixed(0)}%',
                subtext: bbPct > 80 ? 'Near upper band' : bbPct < 20 ? 'Near lower band' : 'Mid range',
                color: bbPct > 80 ? AppTheme.red : bbPct < 20 ? AppTheme.green : Colors.orange,
                barValue: bbPct / 100,
                barColor: bbPct > 80 ? AppTheme.red : bbPct < 20 ? AppTheme.green : Colors.orange,
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final double? barValue;
  final Color? barColor;
  const _IndicatorTile({
    required this.label, required this.value, required this.subtext,
    required this.color, required this.barValue, this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(subtext, style: TextStyle(fontSize: 10, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (barValue != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barValue,
                minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor ?? color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Signals ───────────────────────────────────────────────────────────────────

class _SignalsCard extends StatelessWidget {
  final SignalResult signal;
  const _SignalsCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final tech = signal.technical;
    final reasons = tech.reasons;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Technical Signals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Text('Score: ${tech.score > 0 ? '+' : ''}${tech.score}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: tech.score > 0 ? AppTheme.green : tech.score < 0 ? AppTheme.red : Colors.orange,
                  )),
            ]),
            const SizedBox(height: 10),
            if (reasons.isEmpty)
              const Text('Insufficient data for signals.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
            else
              ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle, size: 7, color: AppTheme.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

// ── ML prediction ─────────────────────────────────────────────────────────────

class _MLCard extends StatelessWidget {
  final MLSignal ml;
  const _MLCard({required this.ml});

  @override
  Widget build(BuildContext context) {
    final prob = ml.probabilityUp ?? 0.5;
    final color = prob >= 0.6 ? AppTheme.green : prob <= 0.4 ? AppTheme.red : Colors.orange;
    final label = prob >= 0.65 ? 'Likely Up' : prob <= 0.35 ? 'Likely Down' : 'Uncertain';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.psychology_rounded, size: 16, color: AppTheme.blue),
              const SizedBox(width: 6),
              const Text('ML Prediction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              if (ml.horizonDays != null)
                Text('${ml.horizonDays}-day horizon',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${(prob * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('probability', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text('price goes UP', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ]),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: prob,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Down', style: TextStyle(fontSize: 9, color: AppTheme.red)),
                        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                        const Text('Up', style: TextStyle(fontSize: 9, color: AppTheme.green)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (ml.backtestAccuracy != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text('${(ml.backtestAccuracy! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.blue)),
                    const Text('model', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    const Text('accuracy', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ]),
              ],
            ),
            if (ml.samplesUsed != null) ...[
              const SizedBox(height: 8),
              Text('Trained on ${ml.samplesUsed} data points (logistic regression)',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Candlestick patterns ──────────────────────────────────────────────────────

class _PatternsCard extends StatelessWidget {
  final List<CandlePattern> patterns;
  const _PatternsCard({required this.patterns});

  Color _color(String type) {
    if (type == 'bullish') return AppTheme.green;
    if (type == 'bearish') return AppTheme.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.candlestick_chart_rounded, size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text('Candlestick Patterns', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            ...patterns.map((p) {
              final c = _color(p.type);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        p.type.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                        const SizedBox(height: 2),
                        Text(p.description,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Support / Resistance / Pivot levels ───────────────────────────────────────

class _LevelsCard extends StatelessWidget {
  final Levels levels;
  final double price;
  const _LevelsCard({required this.levels, required this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Key Price Levels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            if (levels.context.isNotEmpty)
              Text(levels.context,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            const Text('Pivot Points (Daily)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            _PivotRow(label: 'R3', value: levels.r3, price: price, color: AppTheme.red),
            _PivotRow(label: 'R2', value: levels.r2, price: price, color: AppTheme.red),
            _PivotRow(label: 'R1', value: levels.r1, price: price, color: AppTheme.red),
            _PivotRow(label: 'PP', value: levels.pp, price: price, color: AppTheme.blue),
            _PivotRow(label: 'S1', value: levels.s1, price: price, color: AppTheme.green),
            _PivotRow(label: 'S2', value: levels.s2, price: price, color: AppTheme.green),
            _PivotRow(label: 'S3', value: levels.s3, price: price, color: AppTheme.green),
            if (levels.resistance.isNotEmpty || levels.support.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Swing S/R (60-day)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (levels.resistance.isNotEmpty)
                _SRRow(label: 'Resistance', values: levels.resistance.reversed.toList(), color: AppTheme.red),
              if (levels.support.isNotEmpty)
                _SRRow(label: 'Support', values: levels.support, color: AppTheme.green),
            ],
          ],
        ),
      ),
    );
  }
}

class _PivotRow extends StatelessWidget {
  final String label;
  final double value;
  final double price;
  final Color color;
  const _PivotRow({required this.label, required this.value, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    final dist = (value - price) / price * 100;
    final isCurrent = dist.abs() < 0.5;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: isCurrent
          ? BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6))
          : null,
      child: Row(children: [
        Container(
          width: 30,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: isCurrent ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
              color: isCurrent ? Colors.white : color)),
        ),
        const SizedBox(width: 10),
        Text('₹${value.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent ? color : AppTheme.textPrimary)),
        const Spacer(),
        Text('${dist >= 0 ? '+' : ''}${dist.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11,
                color: dist > 0 ? AppTheme.red : AppTheme.green,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SRRow extends StatelessWidget {
  final String label;
  final List<double> values;
  final Color color;
  const _SRRow({required this.label, required this.values, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(
          values.map((v) => '₹${v.toStringAsFixed(0)}').join('  •  '),
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        )),
      ],
    ),
  );
}

// ── News ──────────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final List<NewsItem> news;
  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.newspaper_rounded, size: 16, color: AppTheme.blue),
              const SizedBox(width: 6),
              const Text('Latest News', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            ...news.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(item.publisher,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text(_formatTime(item.publishTime),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ]),
                if (item != news.take(5).last)
                  const Divider(height: 14, thickness: 0.5),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
