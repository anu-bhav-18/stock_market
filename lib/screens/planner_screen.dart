import 'package:flutter/material.dart';
import '../services/planner_service.dart';
import '../theme.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<TradeEntry> _trades = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    final trades = await PlannerService.getTrades();
    if (mounted) setState(() { _trades = trades; _loading = false; });
  }

  List<TradeEntry> get _open   => _trades.where((t) => t.status == TradeStatus.open).toList();
  List<TradeEntry> get _closed => _trades.where((t) => t.status == TradeStatus.closed).toList()
      ..sort((a, b) => (b.exitDate ?? b.entryDate).compareTo(a.exitDate ?? a.entryDate));

  double get _totalPnl => _closed.fold(0, (s, t) => s + (t.pnl(t.exitPrice ?? t.entryPrice)));
  int get _winners => _closed.where((t) => t.pnl(t.exitPrice ?? t.entryPrice) > 0).length;

  Future<void> _showAddDialog() async {
    final symCtrl    = TextEditingController();
    final nameCtrl   = TextEditingController();
    final entryCtrl  = TextEditingController();
    final qtyCtrl    = TextEditingController();
    final slCtrl     = TextEditingController();
    final tgtCtrl    = TextEditingController();
    final notesCtrl  = TextEditingController();
    TradeSide side   = TradeSide.buy;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('New Trade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: symCtrl, textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Symbol *', isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', isDense: true))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Side:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('BUY'), selected: side == TradeSide.buy,
                    selectedColor: AppTheme.green.withValues(alpha: 0.2),
                    onSelected: (_) => setSt(() => side = TradeSide.buy)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('SELL'), selected: side == TradeSide.sell,
                    selectedColor: AppTheme.red.withValues(alpha: 0.2),
                    onSelected: (_) => setSt(() => side = TradeSide.sell)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: entryCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Entry Price *', prefixText: '₹', isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty *', isDense: true))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: slCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stop Loss', prefixText: '₹', isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: tgtCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target', prefixText: '₹', isDense: true))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes / Reason', isDense: true)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final sym   = symCtrl.text.trim().toUpperCase();
                    final entry = double.tryParse(entryCtrl.text.trim()) ?? 0;
                    final qty   = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    if (sym.isEmpty || entry <= 0 || qty <= 0) return;
                    final trade = TradeEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      symbol: sym,
                      name: nameCtrl.text.trim().isEmpty ? sym : nameCtrl.text.trim(),
                      side: side,
                      entryPrice: entry,
                      qty: qty,
                      stopLoss: double.tryParse(slCtrl.text.trim()),
                      target: double.tryParse(tgtCtrl.text.trim()),
                      notes: notesCtrl.text.trim(),
                      entryDate: DateTime.now(),
                    );
                    await PlannerService.addTrade(trade);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  child: const Text('Add Trade'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    symCtrl.dispose(); nameCtrl.dispose(); entryCtrl.dispose();
    qtyCtrl.dispose(); slCtrl.dispose(); tgtCtrl.dispose(); notesCtrl.dispose();
  }

  Future<void> _closeTrade(TradeEntry t) async {
    final ctrl = TextEditingController(text: t.entryPrice.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${t.symbol}'),
        content: TextField(
          controller: ctrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Exit Price', prefixText: '₹'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final exit = double.tryParse(ctrl.text.trim()) ?? 0;
              if (exit <= 0) return;
              t.exitPrice = exit;
              t.exitDate  = DateTime.now();
              t.status    = TradeStatus.closed;
              await PlannerService.updateTrade(t);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Close Trade'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Planner'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.green,
          indicatorColor: AppTheme.green,
          tabs: [
            Tab(text: 'Open (${_open.length})'),
            Tab(text: 'Journal (${_closed.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Trade', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : TabBarView(
              controller: _tab,
              children: [
                _OpenTab(trades: _open, onClose: _closeTrade, onDelete: (t) async {
                  await PlannerService.removeTrade(t.id);
                  await _load();
                }),
                _JournalTab(trades: _closed, totalPnl: _totalPnl, winners: _winners, onDelete: (t) async {
                  await PlannerService.removeTrade(t.id);
                  await _load();
                }),
              ],
            ),
    );
  }
}

class _OpenTab extends StatelessWidget {
  final List<TradeEntry> trades;
  final Future<void> Function(TradeEntry) onClose;
  final Future<void> Function(TradeEntry) onDelete;
  const _OpenTab({required this.trades, required this.onClose, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.book_outlined, size: 56, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('No open trades', style: TextStyle(color: AppTheme.textSecondary)),
          SizedBox(height: 4),
          Text('Tap + to plan a new trade', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: trades.length,
      itemBuilder: (_, i) => _TradeCard(trade: trades[i], onClose: onClose, onDelete: onDelete),
    );
  }
}

class _TradeCard extends StatelessWidget {
  final TradeEntry trade;
  final Future<void> Function(TradeEntry) onClose;
  final Future<void> Function(TradeEntry) onDelete;
  const _TradeCard({required this.trade, required this.onClose, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isBuy   = trade.side == TradeSide.buy;
    final color   = isBuy ? AppTheme.green : AppTheme.red;
    final hasRR   = trade.rrRatio > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(isBuy ? 'BUY' : 'SELL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(width: 8),
            Text(trade.symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Expanded(child: Text(trade.name,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis)),
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'close') onClose(trade); if (v == 'delete') onDelete(trade); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'close',  child: Text('Close Trade')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _InfoCell(label: 'Entry', value: '₹${trade.entryPrice.toStringAsFixed(2)}'),
            _InfoCell(label: 'Qty', value: '${trade.qty}'),
            _InfoCell(label: 'Invested', value: '₹${_fmt(trade.invested)}'),
            if (trade.stopLoss != null)
              _InfoCell(label: 'SL', value: '₹${trade.stopLoss!.toStringAsFixed(2)}', color: AppTheme.red),
            if (trade.target != null)
              _InfoCell(label: 'Target', value: '₹${trade.target!.toStringAsFixed(2)}', color: AppTheme.green),
          ]),
          if (hasRR) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('R:R  ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('1 : ${trade.rrRatio.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: trade.rrRatio >= 2 ? AppTheme.green : trade.rrRatio >= 1 ? Colors.orange : AppTheme.red)),
              const SizedBox(width: 12),
              Text('Risk: ₹${_fmt(trade.riskAmount)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.red)),
              const SizedBox(width: 8),
              Text('Reward: ₹${_fmt(trade.rewardAmount)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.green)),
            ]),
          ],
          if (trade.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(trade.notes,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoCell({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ],
  ));
}

class _JournalTab extends StatelessWidget {
  final List<TradeEntry> trades;
  final double totalPnl;
  final int winners;
  final Future<void> Function(TradeEntry) onDelete;
  const _JournalTab({required this.trades, required this.totalPnl, required this.winners, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const Center(child: Text('No closed trades yet', style: TextStyle(color: AppTheme.textSecondary)));
    }
    final winRate = trades.isEmpty ? 0.0 : winners / trades.length * 100;
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: totalPnl >= 0
                ? [AppTheme.green.withValues(alpha: 0.15), AppTheme.green.withValues(alpha: 0.05)]
                : [AppTheme.red.withValues(alpha: 0.15), AppTheme.red.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total P&L', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text('${totalPnl >= 0 ? '+' : ''}₹${totalPnl.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: totalPnl >= 0 ? AppTheme.green : AppTheme.red)),
          ])),
          _StatBubble(label: 'Trades', value: '${trades.length}'),
          const SizedBox(width: 10),
          _StatBubble(label: 'Win Rate', value: '${winRate.toStringAsFixed(0)}%',
              color: winRate >= 50 ? AppTheme.green : AppTheme.red),
          const SizedBox(width: 10),
          _StatBubble(label: 'Winners', value: '$winners'),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          itemCount: trades.length,
          itemBuilder: (_, i) {
            final t   = trades[i];
            final pnl = t.pnl(t.exitPrice ?? t.entryPrice);
            final isWin = pnl >= 0;
            return Dismissible(
              key: Key(t.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: AppTheme.red,
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) => onDelete(t),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isWin ? AppTheme.green.withValues(alpha: 0.1) : AppTheme.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isWin ? Icons.trending_up : Icons.trending_down,
                          color: isWin ? AppTheme.green : AppTheme.red, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(t.symbol, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.side == TradeSide.buy
                                ? AppTheme.green.withValues(alpha: 0.1)
                                : AppTheme.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t.side.name.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                  color: t.side == TradeSide.buy ? AppTheme.green : AppTheme.red)),
                        ),
                      ]),
                      Text('Entry ₹${t.entryPrice.toStringAsFixed(2)} → Exit ₹${(t.exitPrice ?? 0).toStringAsFixed(2)} × ${t.qty}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${isWin ? '+' : ''}₹${pnl.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                              color: isWin ? AppTheme.green : AppTheme.red)),
                      Text('${t.pnlPct(t.exitPrice ?? t.entryPrice).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11, color: isWin ? AppTheme.green : AppTheme.red)),
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBubble({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
        color: color ?? AppTheme.textPrimary)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
  ]);
}
