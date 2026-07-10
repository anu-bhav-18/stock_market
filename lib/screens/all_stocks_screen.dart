import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'stock_detail_screen.dart';

class AllStocksScreen extends StatefulWidget {
  const AllStocksScreen({super.key});

  @override
  State<AllStocksScreen> createState() => _AllStocksScreenState();
}

class _AllStocksScreenState extends State<AllStocksScreen> {
  static const _indices = [
    'All', 'Nifty 50', 'Nifty Next 50', 'Nifty Bank', 'Nifty IT',
    'Nifty Pharma', 'Nifty Auto', 'Nifty FMCG', 'Nifty Metal',
    'Nifty Midcap 50',
  ];

  String _index = 'All';
  List<Stock> _all = [];
  List<Stock> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stocks = await ApiService.fetchStocks(index: _index);
      if (mounted) {
        setState(() {
          _all = stocks;
          _loading = false;
        });
        _filter();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((s) =>
              s.symbol.toLowerCase().contains(q) ||
              s.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Stocks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(children: [
              // Search bar
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name or symbol…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              // Index filter chips
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _indices.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final idx = _indices[i];
                    final active = idx == _index;
                    return GestureDetector(
                      onTap: () {
                        if (idx == _index) return;
                        setState(() => _index = idx);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.green : AppTheme.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: active ? AppTheme.green : Colors.grey.shade300),
                        ),
                        child: Text(idx,
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppTheme.textSecondary,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ]),
                  ),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      Text('${_filtered.length} stocks',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ]),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No stocks match "${_searchCtrl.text}"',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5),
                            itemBuilder: (_, i) => _StockRow(stock: _filtered[i]),
                          ),
                  ),
                ]),
    );
  }
}

class _StockRow extends StatelessWidget {
  final Stock stock;
  const _StockRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    final sym = stock.symbol.replaceAll('.NS', '');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          sym.length > 3 ? sym.substring(0, 3) : sym,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.green),
        ),
      ),
      title: Text(stock.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(sym,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: stock.symbol, name: stock.name),
      )),
    );
  }
}
