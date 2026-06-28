import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/signal_pill.dart';

class TopMoversScreen extends StatefulWidget {
  const TopMoversScreen({super.key});

  @override
  State<TopMoversScreen> createState() => _TopMoversScreenState();
}

class _TopMoversScreenState extends State<TopMoversScreen> {
  int _horizon = 5;
  List<MoverStock>? _results;
  bool _scanning = false;
  String? _error;

  final List<int> _horizons = [3, 5, 10, 20];

  Future<void> _scan() async {
    setState(() { _scanning = true; _results = null; _error = null; });
    try {
      final r = await ApiService.fetchScreener(horizon: _horizon);
      if (mounted) setState(() { _results = r; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _scanning = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🚀 Top Movers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _horizon,
                        decoration: const InputDecoration(labelText: 'Horizon'),
                        items: _horizons
                            .map((h) => DropdownMenuItem(value: h, child: Text('$h trading days')))
                            .toList(),
                        onChanged: (v) => setState(() => _horizon = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search, size: 18),
                      label: const Text('Scan Nifty 50'),
                    ),
                  ],
                ),
                if (_scanning) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: AppTheme.green),
                  const SizedBox(height: 6),
                  const Text('Analysing 50 stocks, this may take a minute…',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.red.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Error: $_error', style: const TextStyle(color: AppTheme.red)),
              ),
            ),
          if (_results == null && !_scanning && _error == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 56, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Press Scan to rank all Nifty 50 stocks',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    SizedBox(height: 4),
                    Text('Fetches live data for 50 stocks — takes ~1 min',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          if (_results != null)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _MoverCard(stock: _results![i], rank: i + 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoverCard extends StatelessWidget {
  final MoverStock stock;
  final int rank;

  const _MoverCard({required this.stock, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isUp = stock.dayChangePct >= 0;
    final changeColor = isUp ? AppTheme.green : AppTheme.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? AppTheme.green : AppTheme.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: rank <= 3 ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                  Text(stock.symbol, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${stock.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '${isUp ? '+' : ''}${stock.dayChangePct.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 12, color: changeColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SignalPill(label: stock.technicalLabel),
                const SizedBox(height: 4),
                Text('${stock.compositeScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
