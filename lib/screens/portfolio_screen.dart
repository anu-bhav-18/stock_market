import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/portfolio_service.dart';
import '../theme.dart';
import 'stock_detail_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<_HoldingView> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final holdings = await PortfolioService.getHoldings();
    final views = <_HoldingView>[];
    for (final h in holdings) {
      double? ltp;
      try {
        final q = await ApiService.fetchQuote(h.symbol);
        ltp = q.price;
      } catch (_) {}
      views.add(_HoldingView(holding: h, ltp: ltp));
    }
    if (mounted) setState(() { _items = views; _loading = false; });
  }

  Future<void> _addDialog() async {
    final symCtrl  = TextEditingController();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl  = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Holding'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: symCtrl,  decoration: const InputDecoration(labelText: 'Symbol (e.g. RELIANCE.NS)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Buy Price (₹)')),
            TextField(controller: qtyCtrl,  keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sym   = symCtrl.text.trim().toUpperCase();
              final name  = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
              final qty   = double.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (sym.isEmpty || price <= 0 || qty <= 0) return;
              await PortfolioService.addHolding(Holding(
                symbol: sym.contains('.') ? sym : '$sym.NS',
                name: name.isEmpty ? sym : name,
                buyPrice: price,
                quantity: qty,
                buyDate: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    symCtrl.dispose(); nameCtrl.dispose(); priceCtrl.dispose(); qtyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalInvested = _items.fold(0.0, (s, v) => s + v.holding.invested());
    final totalCurrent  = _items.fold(0.0, (s, v) => s + (v.ltp != null ? v.holding.currentValue(v.ltp!) : v.holding.invested()));
    final totalPnl      = totalCurrent - totalInvested;
    final totalPnlPct   = totalInvested > 0 ? totalPnl / totalInvested * 100 : 0.0;
    final isProfit      = totalPnl >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _addDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : _items.isEmpty
              ? _EmptyState(onAdd: _addDialog)
              : Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isProfit
                              ? [AppTheme.green.withValues(alpha: 0.8), AppTheme.green]
                              : [AppTheme.red.withValues(alpha: 0.8), AppTheme.red],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SummaryCol('Invested', '₹${_fmt(totalInvested)}', Colors.white70),
                              _SummaryCol('Current', '₹${_fmt(totalCurrent)}', Colors.white),
                              _SummaryCol('P&L', '${isProfit ? '+' : ''}₹${_fmt(totalPnl)}', Colors.white),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${isProfit ? '+' : ''}${totalPnlPct.toStringAsFixed(2)}% overall return',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: AppTheme.green,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _HoldingCard(
                            view: _items[i],
                            onDelete: () async {
                              await PortfolioService.removeHolding(i);
                              _load();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _items.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addDialog,
              backgroundColor: AppTheme.green,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v.abs() >= 100000)   return '${(v / 100000).toStringAsFixed(2)}L';
    return v.toStringAsFixed(0);
  }
}

class _HoldingView {
  final Holding holding;
  final double? ltp;
  const _HoldingView({required this.holding, this.ltp});
}

class _HoldingCard extends StatelessWidget {
  final _HoldingView view;
  final VoidCallback onDelete;
  const _HoldingCard({required this.view, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final h = view.holding;
    final ltp = view.ltp ?? h.buyPrice;
    final pnl = h.pnl(ltp);
    final pnlPct = h.pnlPct(ltp);
    final isProfit = pnl >= 0;
    final color = isProfit ? AppTheme.green : AppTheme.red;

    return Dismissible(
      key: Key('${h.symbol}_${h.buyDate}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => StockDetailScreen(symbol: h.symbol, name: h.name),
          )),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.symbol.replaceAll('.NS', ''),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(h.name, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${ltp.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat('Qty', h.quantity.toStringAsFixed(0)),
                  _Stat('Avg', '₹${h.buyPrice.toStringAsFixed(1)}'),
                  _Stat('Invested', '₹${h.invested().toStringAsFixed(0)}'),
                  _Stat('P&L', '${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(0)}', color: color),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? AppTheme.textPrimary)),
    ]),
  );
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCol(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: color)),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textSecondary),
      const SizedBox(height: 12),
      const Text('No holdings yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 6),
      const Text('Add your stocks to track P&L', style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 16), label: const Text('Add Holding')),
    ]),
  );
}
