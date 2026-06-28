import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/signal_pill.dart';
import '../widgets/stock_chart.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  List<Stock> _stocks = [];
  Stock? _selected;
  int _horizon = 5;
  SignalResult? _signal;
  List<HistoryPoint> _history = [];
  bool _loadingStocks = true;
  bool _analyzing = false;
  String? _error;

  final List<int> _horizons = [1, 3, 5, 10, 20];

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
      }
    });
  }

  Future<void> _analyze() async {
    if (_selected == null) return;
    setState(() {
      _analyzing = true;
      _signal = null;
      _error = null;
      _history = [];
    });
    try {
      final results = await Future.wait([
        ApiService.fetchSignal(_selected!.symbol, horizon: _horizon),
        ApiService.fetchHistory(_selected!.symbol, period: '1y'),
      ]);
      if (mounted) {
        setState(() {
          _signal = results[0] as SignalResult;
          _history = results[1] as List<HistoryPoint>;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _analyzing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔮 Stock Prediction')),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _StockDropdown(
                        stocks: _stocks,
                        selected: _selected,
                        onChanged: (s) => setState(() { _selected = s; _signal = null; }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _horizon,
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _analyzing ? null : _analyze,
                    child: _analyzing
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Analyze'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(message: _error!),
                ],
                if (_signal != null) ...[
                  const SizedBox(height: 16),
                  _SignalCards(signal: _signal!, horizon: _horizon),
                  const SizedBox(height: 12),
                  if (_signal!.technical.reasons.isNotEmpty) _ReasonsCard(reasons: _signal!.technical.reasons),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ChartCard(history: _history),
                  ],
                ],
                const SizedBox(height: 24),
                const _Disclaimer(),
              ],
            ),
    );
  }
}

class _SignalCards extends StatelessWidget {
  final SignalResult signal;
  final int horizon;

  const _SignalCards({required this.signal, required this.horizon});

  @override
  Widget build(BuildContext context) {
    final ml = signal.ml;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _InfoCard(
              title: 'Technical Signal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalPill(label: signal.technical.label),
                  const SizedBox(height: 6),
                  Text('Score: ${signal.technical.score} / 100',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: _InfoCard(
              title: 'ML Signal',
              child: ml.available
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(ml.probabilityUp! * 100).toStringAsFixed(1)}% prob. rising in $horizon days',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (ml.backtestAccuracy != null)
                          Text(
                            'Backtest acc: ${(ml.backtestAccuracy! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                      ],
                    )
                  : Text(ml.reason ?? 'Not enough history',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )),
          ],
        ),
        const SizedBox(height: 10),
        _InfoCard(
          title: 'Composite Outlook',
          child: Row(
            children: [
              Text(
                '${signal.compositeScore.toStringAsFixed(0)}/100',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: signal.compositeScore / 100,
                    color: AppTheme.green,
                    backgroundColor: Colors.grey.shade200,
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonsCard extends StatelessWidget {
  final List<String> reasons;
  const _ReasonsCard({required this.reasons});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why this signal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...reasons.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<HistoryPoint> history;
  const _ChartCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price Chart (1 year)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            StockChart(data: history, height: 220),
            const SizedBox(height: 16),
            const Text('RSI (14)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            RSIChart(data: history),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StockDropdown extends StatelessWidget {
  final List<Stock> stocks;
  final Stock? selected;
  final void Function(Stock?) onChanged;

  const _StockDropdown({required this.stocks, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Stock>(
      value: selected,
      decoration: const InputDecoration(labelText: 'Stock'),
      isExpanded: true,
      items: stocks
          .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Error: $message', style: const TextStyle(color: AppTheme.red)),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '⚠️ Educational use only. Predictions are statistical estimates from historical data. Not investment advice.',
      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      textAlign: TextAlign.center,
    );
  }
}
