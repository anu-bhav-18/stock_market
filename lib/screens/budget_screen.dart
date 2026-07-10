import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/signal_pill.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Stock> _stocks = [];
  Stock? _selected;
  int _horizon = 10;
  final _budgetCtrl = TextEditingController(text: '25000');
  Quote? _quote;
  SignalResult? _signal;
  bool _loadingStocks = true;
  bool _loadingQuote = false;
  bool _calculating = false;
  double _expectedReturnPct = 0;
  bool _showProjection = false;
  String? _error;

  final List<int> _horizons = [3, 5, 10, 20, 60];

  @override
  void initState() {
    super.initState();
    ApiService.fetchStocks().then((s) {
      if (mounted) {
        setState(() {
          _stocks = s;
          _selected = s.isNotEmpty ? s.first : null;
          _loadingStocks = false;
        });
        if (s.isNotEmpty) _loadQuote(s.first);
      }
    });
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuote(Stock stock) async {
    setState(() { _loadingQuote = true; _quote = null; _signal = null; _showProjection = false; });
    try {
      final q = await ApiService.fetchQuote(stock.symbol);
      if (mounted) setState(() { _quote = q; _loadingQuote = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  Future<void> _calculate() async {
    if (_selected == null || _quote == null) return;
    setState(() { _calculating = true; _error = null; _showProjection = false; });
    try {
      final sig = await ApiService.fetchSignal(_selected!.symbol, horizon: _horizon);
      if (mounted) {
        final probUp = sig.ml.available ? sig.ml.probabilityUp! : 0.5;
        setState(() {
          _signal = sig;
          _expectedReturnPct = ((probUp * 2) - 1) * 10;
          _calculating = false;
          _showProjection = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _calculating = false; });
    }
  }

  double get _budget => double.tryParse(_budgetCtrl.text) ?? 0;
  int get _shares => _quote != null ? (_budget ~/ _quote!.price) : 0;
  double get _invested => _shares * (_quote?.price ?? 0);
  double get _leftover => _budget - _invested;
  double get _projectedValue => _invested * (1 + _expectedReturnPct / 100);
  double get _projectedGain => _projectedValue - _invested;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ðŸ§® Budget Calculator')),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Stock>(
                        initialValue: _selected,
                        decoration: const InputDecoration(labelText: 'Stock'),
                        isExpanded: true,
                        items: _stocks
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (s) {
                          if (s == null) return;
                          setState(() { _selected = s; _showProjection = false; });
                          _loadQuote(s);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _horizon,
                        decoration: const InputDecoration(labelText: 'Horizon'),
                        items: _horizons
                            .map((h) => DropdownMenuItem(value: h, child: Text('$h days')))
                            .toList(),
                        onChanged: (v) => setState(() => _horizon = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _budgetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your budget (â‚¹)',
                    prefixText: 'â‚¹ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                if (_loadingQuote)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.green)))
                else if (_quote != null) ...[
                  _AllocationCard(
                    quote: _quote!,
                    shares: _shares,
                    invested: _invested,
                    leftover: _leftover,
                  ),
                  const SizedBox(height: 14),
                  if (_shares > 0) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _calculating ? null : _calculate,
                        child: _calculating
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Calculate Projection'),
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Budget is less than one share (â‚¹${_quote!.price.toStringAsFixed(2)}). Increase budget to see projection.',
                        style: const TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.red.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('Error: $_error', style: const TextStyle(color: AppTheme.red)),
                  ),
                ],
                if (_showProjection && _signal != null) ...[
                  const SizedBox(height: 16),
                  _ProjectionCard(
                    signal: _signal!,
                    invested: _invested,
                    projectedValue: _projectedValue,
                    projectedGain: _projectedGain,
                    expectedReturnPct: _expectedReturnPct,
                    horizon: _horizon,
                    onSliderChanged: (v) => setState(() => _expectedReturnPct = v),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'âš ï¸ Projection is a rough heuristic from model conviction, not a price target. Educational use only.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final Quote quote;
  final int shares;
  final double invested;
  final double leftover;

  const _AllocationCard({required this.quote, required this.shares, required this.invested, required this.leftover});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allocation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Current Price', value: 'â‚¹${quote.price.toStringAsFixed(2)}')),
                Expanded(child: _Stat(label: 'Shares you can buy', value: '$shares')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Amount invested', value: 'â‚¹${invested.toStringAsFixed(0)}')),
                Expanded(child: _Stat(label: 'Leftover', value: 'â‚¹${leftover.toStringAsFixed(0)}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final SignalResult signal;
  final double invested;
  final double projectedValue;
  final double projectedGain;
  final double expectedReturnPct;
  final int horizon;
  final void Function(double) onSliderChanged;

  const _ProjectionCard({
    required this.signal,
    required this.invested,
    required this.projectedValue,
    required this.projectedGain,
    required this.expectedReturnPct,
    required this.horizon,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = projectedGain >= 0;
    final color = isUp ? AppTheme.green : AppTheme.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Projected Outcome', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Projected value', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text('â‚¹${projectedValue.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text(
                        '${isUp ? '+' : ''}${expectedReturnPct.toStringAsFixed(1)}%  (${isUp ? '+' : ''}â‚¹${projectedGain.toStringAsFixed(0)})',
                        style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SignalPill(label: signal.technical.label),
                    const SizedBox(height: 4),
                    if (signal.ml.available)
                      Text(
                        'ML: ${(signal.ml.probabilityUp! * 100).toStringAsFixed(1)}% up',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    Text('Score: ${signal.compositeScore.toStringAsFixed(0)}/100',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Adjust expected return: ${expectedReturnPct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Slider(
              value: expectedReturnPct.clamp(-30, 30),
              min: -30,
              max: 30,
              divisions: 120,
              activeColor: expectedReturnPct >= 0 ? AppTheme.green : AppTheme.red,
              onChanged: onSliderChanged,
            ),
          ],
        ),
      ),
    );
  }
}

