import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/watchlist_service.dart';
import '../theme.dart';
import '../widgets/stock_chart.dart';
import '../widgets/signal_pill.dart';

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
    });
    final watched = await WatchlistService.isWatched(stock.symbol);
    if (mounted) setState(() => _watched = watched);

    try {
      final results = await Future.wait([
        ApiService.fetchQuote(stock.symbol),
        ApiService.fetchHistory(stock.symbol, period: '6mo'),
        ApiService.fetchSignal(stock.symbol),
      ]);
      if (mounted) {
        setState(() {
          _quote = results[0] as Quote;
          _history = results[1] as List<HistoryPoint>;
          _signal = results[2] as SignalResult;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
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
  final bool loading;

  const _StockDetail({
    required this.stock, this.quote, required this.history,
    this.signal, required this.loading,
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => const Text(
        '⚠️ Educational use only. Not investment advice.',
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
      );
}
