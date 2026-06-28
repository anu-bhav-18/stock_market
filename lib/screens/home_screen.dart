import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/stock_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Stock> _stocks = [];
  List<Stock> _filtered = [];
  Stock? _selected;
  Quote? _quote;
  List<HistoryPoint> _history = [];
  bool _loadingStocks = true;
  bool _loadingData = false;
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
    try {
      final stocks = await ApiService.fetchStocks();
      setState(() {
        _stocks = stocks;
        _filtered = stocks.take(10).toList();
        _loadingStocks = false;
      });
      if (stocks.isNotEmpty) _selectStock(stocks.first);
    } catch (e) {
      setState(() => _loadingStocks = false);
    }
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _stocks.take(10).toList()
          : _stocks
              .where((s) =>
                  s.name.toLowerCase().contains(lower) ||
                  s.symbol.toLowerCase().contains(lower))
              .take(10)
              .toList();
    });
  }

  Future<void> _selectStock(Stock stock) async {
    setState(() {
      _selected = stock;
      _loadingData = true;
      _quote = null;
      _history = [];
    });
    try {
      final results = await Future.wait([
        ApiService.fetchQuote(stock.symbol),
        ApiService.fetchHistory(stock.symbol, period: '6mo'),
      ]);
      if (mounted) {
        setState(() {
          _quote = results[0] as Quote;
          _history = results[1] as List<HistoryPoint>;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockSense 📈'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search stocks (e.g. RELIANCE, TCS)',
                    prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                _QuickPicks(stocks: _filtered, selected: _selected, onSelect: _selectStock),
                const SizedBox(height: 16),
                if (_selected != null) _StockDetail(stock: _selected!, quote: _quote, history: _history, loading: _loadingData),
                const SizedBox(height: 24),
                _NavigationCards(),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick pick', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stocks.map((s) {
            final isSelected = selected?.symbol == s.symbol;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.green : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppTheme.green : Colors.grey.shade300),
                ),
                child: Text(
                  s.symbol.replaceAll('.NS', ''),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StockDetail extends StatelessWidget {
  final Stock stock;
  final Quote? quote;
  final List<HistoryPoint> history;
  final bool loading;

  const _StockDetail({required this.stock, this.quote, required this.history, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stock.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(stock.symbol, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.green)))
            else ...[
              if (quote != null) ...[
                _PriceRow(quote: quote!),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricChip(label: 'Prev Close', value: '₹${quote!.prevClose.toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    if (history.isNotEmpty)
                      _MetricChip(
                        label: '6M High',
                        value: '₹${history.map((h) => h.high).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}',
                      ),
                  ],
                ),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockChart(data: history),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _Legend(color: AppTheme.green, label: 'Close'),
                    SizedBox(width: 12),
                    _Legend(color: AppTheme.blue, label: 'SMA 20'),
                    SizedBox(width: 12),
                    _Legend(color: AppTheme.red, label: 'SMA 50'),
                  ],
                ),
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
        Text('₹${quote.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Text(
          '${isUp ? '+' : ''}${quote.changePct.toStringAsFixed(2)}%',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 14, height: 3, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ]);
  }
}

class _NavigationCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Explore', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            const Text('🔮  Stock Prediction — technical + ML view',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('💰  Expected Return — historical CAGR & volatility',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('🚀  Top Movers — screen Nifty 50 by bullishness',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('🧮  Budget Calculator — shares + projected outcome',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Educational use only. Not investment advice.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
