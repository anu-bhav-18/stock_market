import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/watchlist_service.dart';
import '../theme.dart';
import '../widgets/signal_pill.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<_WatchItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final symbols = await WatchlistService.getSymbols();
    if (symbols.isEmpty) {
      if (mounted) setState(() { _items = []; _loading = false; });
      return;
    }
    final futures = symbols.map((s) => _fetchItem(s));
    final results = await Future.wait(futures);
    if (mounted) setState(() { _items = results.whereType<_WatchItem>().toList(); _loading = false; });
  }

  Future<_WatchItem?> _fetchItem(String symbol) async {
    try {
      final quote = await ApiService.fetchQuote(symbol);
      return _WatchItem(symbol: symbol, quote: quote);
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeItem(String symbol) async {
    await WatchlistService.remove(symbol);
    setState(() => _items.removeWhere((i) => i.symbol == symbol));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⭐ Watchlist'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : _items.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  color: AppTheme.green,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _WatchCard(
                      item: _items[i],
                      onRemove: () => _removeItem(_items[i].symbol),
                    ),
                  ),
                ),
    );
  }
}

class _WatchItem {
  final String symbol;
  final Quote quote;
  const _WatchItem({required this.symbol, required this.quote});
}

class _WatchCard extends StatefulWidget {
  final _WatchItem item;
  final VoidCallback onRemove;
  const _WatchCard({required this.item, required this.onRemove});

  @override
  State<_WatchCard> createState() => _WatchCardState();
}

class _WatchCardState extends State<_WatchCard> {
  SignalResult? _signal;

  @override
  void initState() {
    super.initState();
    _loadSignal();
  }

  Future<void> _loadSignal() async {
    try {
      final s = await ApiService.fetchSignal(widget.item.symbol);
      if (mounted) setState(() => _signal = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.item.quote;
    final isUp = q.changePct >= 0;
    return Dismissible(
      key: Key(widget.item.symbol),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => widget.onRemove(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.symbol.replaceAll('.NS', ''),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (_signal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SignalPill(label: _signal!.technical.label),
                      )
                    else
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${q.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                    '${isUp ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 13, color: isUp ? AppTheme.green : AppTheme.red, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_border_rounded, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('No stocks in watchlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Tap ☆ on any stock to add it here',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
