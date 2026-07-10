import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/watchlist_service.dart';
import '../theme.dart';
import '../widgets/stock_chart.dart';
import '../widgets/signal_pill.dart';
import 'stock_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _indices = [
    'Nifty 50', 'Nifty Next 50', 'Nifty Bank', 'Nifty IT',
    'Nifty Pharma', 'Nifty Auto', 'Nifty FMCG', 'Nifty Metal', 'Nifty Midcap 50',
  ];

  String _selectedIndex = 'Nifty 50';
  List<Stock> _stocks = [];
  List<Stock> _filtered = [];
  Stock? _selected;
  Quote? _quote;
  List<HistoryPoint> _history = [];
  SignalResult? _signal;
  Levels? _levels;
  bool _loadingStocks = true;
  bool _loadingData = false;
  bool _watched = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    setState(() => _loadingStocks = true);
    try {
      final stocks = await ApiService.fetchStocks(index: _selectedIndex);
      if (!mounted) return;
      setState(() {
        _stocks = stocks;
        _filtered = stocks.take(12).toList();
        _loadingStocks = false;
      });
      if (stocks.isNotEmpty) _selectStock(stocks.first);
    } catch (e) {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _stocks.take(12).toList()
          : _stocks
              .where((s) =>
                  s.name.toLowerCase().contains(lower) ||
                  s.symbol.toLowerCase().contains(lower))
              .take(12)
              .toList();
    });
  }

  Future<void> _selectStock(Stock stock) async {
    setState(() {
      _selected = stock;
      _loadingData = true;
      _quote = null;
      _history = [];
      _signal = null;
      _levels = null;
    });
    final watched = await WatchlistService.isWatched(stock.symbol);
    if (mounted) setState(() => _watched = watched);

    // Fetch each independently so a signal/ML failure doesn't block price+chart
    Quote? quote;
    List<HistoryPoint> history = [];
    SignalResult? signal;
    Levels? levels;

    await Future.wait([
      ApiService.fetchQuote(stock.symbol).then((v) { quote = v; }).catchError((_) {}),
      ApiService.fetchHistory(stock.symbol, period: '6mo').then((v) { history = v; }).catchError((_) {}),
      ApiService.fetchSignal(stock.symbol).then((v) { signal = v; }).catchError((_) {}),
      ApiService.fetchLevels(stock.symbol).then((v) { levels = v; }).catchError((_) {}),
    ]);

    if (mounted) {
      setState(() {
        _quote = quote;
        _history = history;
        _signal = signal;
        _levels = levels;
        _loadingData = false;
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_selected == null) return;
    await WatchlistService.toggle(_selected!.symbol);
    final w = await WatchlistService.isWatched(_selected!.symbol);
    if (mounted) setState(() => _watched = w);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockSense 📈'),
        actions: [
          if (_selected != null)
            IconButton(
              icon: Icon(_watched ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _watched ? Colors.amber : null),
              onPressed: _toggleWatchlist,
            ),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Column(
        children: [
          // Index filter chips
          _IndexBar(
            indices: _indices,
            selected: _selectedIndex,
            onChanged: (i) {
              setState(() { _selectedIndex = i; _searchCtrl.clear(); });
              _loadStocks();
            },
          ),
          Expanded(
            child: _loadingStocks
                ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search stocks…',
                          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _QuickPicks(stocks: _filtered, selected: _selected, onSelect: _selectStock),
                      const SizedBox(height: 14),
                      if (_selected != null)
                        _StockDetail(
                          stock: _selected!,
                          quote: _quote,
                          history: _history,
                          signal: _signal,
                          levels: _levels,
                          loading: _loadingData,
                        ),
                      const SizedBox(height: 16),
                      const _Disclaimer(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _IndexBar extends StatelessWidget {
  final List<String> indices;
  final String selected;
  final void Function(String) onChanged;

  const _IndexBar({required this.indices, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: indices.map((i) {
          final active = i == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: active ? AppTheme.green : AppTheme.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  i,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  final List<Stock> stocks;
  final Stock? selected;
  final void Function(Stock) onSelect;

  const _QuickPicks({required this.stocks, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: stocks.map((s) {
        final active = selected?.symbol == s.symbol;
        return GestureDetector(
          onTap: () => onSelect(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppTheme.green : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? AppTheme.green : Colors.grey.shade300),
            ),
            child: Text(
              s.symbol.replaceAll('.NS', ''),
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StockDetail extends StatelessWidget {
  final Stock stock;
  final Quote? quote;
  final List<HistoryPoint> history;
  final SignalResult? signal;
  final Levels? levels;
  final bool loading;

  const _StockDetail({
    required this.stock, this.quote, required this.history,
    this.signal, this.levels, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stock.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(stock.symbol, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                )),
                if (signal != null) SignalPill(label: signal!.technical.label),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(color: AppTheme.green)))
            else ...[
              if (quote != null) ...[
                _PriceRow(quote: quote!),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Chip(label: 'Prev Close', value: '₹${quote!.prevClose.toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    if (history.isNotEmpty)
                      _Chip(label: '6M High', value: '₹${history.map((h) => h.high).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'),
                    if (signal != null) ...[
                      const SizedBox(width: 8),
                      _Chip(label: 'Score', value: '${signal!.compositeScore.toStringAsFixed(0)}/100'),
                    ],
                  ],
                ),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 14),
                StockChart(data: history),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(color: AppTheme.green, label: 'Close'),
                    SizedBox(width: 12),
                    _Legend(color: AppTheme.blue, label: 'SMA 20'),
                    SizedBox(width: 12),
                    _Legend(color: AppTheme.red, label: 'SMA 50'),
                  ],
                ),
              ],
              if (signal != null && signal!.technical.reasons.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Signals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 6),
                ...signal!.technical.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                  ]),
                )),
              ],
              if (signal != null && signal!.patterns.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PatternsRow(patterns: signal!.patterns),
              ],
              if (levels != null) ...[
                const SizedBox(height: 14),
                _LevelsCard(levels: levels!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StockDetailScreen(symbol: stock.symbol, name: stock.name),
                  )),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Full Technical Analysis'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.blue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Quote quote;
  const _PriceRow({required this.quote});

  @override
  Widget build(BuildContext context) {
    final isUp = quote.changePct >= 0;
    final color = isUp ? AppTheme.green : AppTheme.red;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('₹${quote.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Text('${isUp ? '+' : ''}${quote.changePct.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]);
}

class _PatternsRow extends StatelessWidget {
  final List<CandlePattern> patterns;
  const _PatternsRow({required this.patterns});

  Color _color(String type) {
    if (type == 'bullish') return AppTheme.green;
    if (type == 'bearish') return AppTheme.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Candlestick Patterns', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: patterns.map((p) => Tooltip(
            message: p.description,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _color(p.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _color(p.type).withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  p.type == 'bullish' ? Icons.trending_up : p.type == 'bearish' ? Icons.trending_down : Icons.drag_handle,
                  size: 12, color: _color(p.type),
                ),
                const SizedBox(width: 4),
                Text(p.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color(p.type))),
              ]),
            ),
          )).toList(),
        ),
        if (patterns.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(patterns.first.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ),
      ],
    );
  }
}

class _LevelsCard extends StatelessWidget {
  final Levels levels;
  const _LevelsCard({required this.levels});

  @override
  Widget build(BuildContext context) {
    final price = levels.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pivot Levels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 6),
        // Resistance levels
        _LevelRow(label: 'R2', value: levels.r2, price: price, isResistance: true),
        _LevelRow(label: 'R1', value: levels.r1, price: price, isResistance: true),
        _LevelRow(label: 'PP', value: levels.pp, price: price, isResistance: null),
        _LevelRow(label: 'S1', value: levels.s1, price: price, isResistance: false),
        _LevelRow(label: 'S2', value: levels.s2, price: price, isResistance: false),
        if (levels.context.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(levels.context,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
        // S/R from price history
        if (levels.resistance.isNotEmpty || levels.support.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Key S/R Levels (60-day)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (levels.resistance.isNotEmpty)
            Row(children: [
              const Text('Resistance: ', style: TextStyle(fontSize: 10, color: AppTheme.red)),
              Expanded(child: Text(
                levels.resistance.reversed.map((v) => '₹${v.toStringAsFixed(0)}').join('  '),
                style: const TextStyle(fontSize: 10, color: AppTheme.red, fontWeight: FontWeight.w600),
              )),
            ]),
          if (levels.support.isNotEmpty)
            Row(children: [
              const Text('Support: ', style: TextStyle(fontSize: 10, color: AppTheme.green)),
              Expanded(child: Text(
                levels.support.map((v) => '₹${v.toStringAsFixed(0)}').join('  '),
                style: const TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w600),
              )),
            ]),
        ],
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  final String label;
  final double value;
  final double price;
  final bool? isResistance; // null = pivot

  const _LevelRow({required this.label, required this.value, required this.price, required this.isResistance});

  @override
  Widget build(BuildContext context) {
    final isCurrent = (value - price).abs() / price < 0.005;
    final color = isResistance == null
        ? AppTheme.blue
        : isResistance! ? AppTheme.red : AppTheme.green;
    final distPct = (value - price) / price * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: isCurrent ? Colors.white : color,
                )),
          ),
          const SizedBox(width: 8),
          Text('₹${value.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 12, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent ? color : AppTheme.textPrimary,
              )),
          const Spacer(),
          Text(
            '${distPct >= 0 ? '+' : ''}${distPct.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 10, color: distPct > 0 ? AppTheme.red : AppTheme.green),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => const Text(
        '⚠️ Educational use only. Not investment advice.',
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
      );
}
