import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/signal_pill.dart';
import 'stock_detail_screen.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  static const _indices = [
    'Nifty 50', 'Nifty Next 50', 'Nifty Bank', 'Nifty IT',
    'Nifty Pharma', 'Nifty Auto', 'Nifty FMCG', 'Nifty Metal', 'Nifty Midcap 50',
  ];

  String _selectedIndex = 'Nifty 50';
  int _horizon = 5;
  List<MoverStock>? _results;
  bool _scanning = false;
  String? _error;

  Future<void> _scan() async {
    setState(() { _scanning = true; _results = null; _error = null; });
    try {
      final r = await ApiService.fetchScreener(index: _selectedIndex, horizon: _horizon);
      if (mounted) setState(() { _results = r; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _scanning = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signals')),
      body: Column(
        children: [
          _FilterBar(
            indices: _indices,
            selectedIndex: _selectedIndex,
            horizon: _horizon,
            scanning: _scanning,
            onIndexChanged: (v) => setState(() { _selectedIndex = v; _results = null; }),
            onHorizonChanged: (v) => setState(() => _horizon = v),
            onScan: _scan,
          ),
          if (_scanning) ...[
            const LinearProgressIndicator(color: AppTheme.green),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Scanning $_selectedIndex...',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: AppTheme.red)),
              ),
            ),
          if (_results == null && !_scanning && _error == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 56, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Select an index and press Scan',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    SizedBox(height: 4),
                    Text('Ranks stocks by technical + ML bullishness score',
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
                itemBuilder: (_, i) => _StockCard(stock: _results![i], rank: i + 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> indices;
  final String selectedIndex;
  final int horizon;
  final bool scanning;
  final void Function(String) onIndexChanged;
  final void Function(int) onHorizonChanged;
  final VoidCallback onScan;

  const _FilterBar({
    required this.indices, required this.selectedIndex, required this.horizon,
    required this.scanning, required this.onIndexChanged,
    required this.onHorizonChanged, required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: selectedIndex,
              decoration: const InputDecoration(labelText: 'Index', isDense: true),
              items: indices.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => onIndexChanged(v!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: horizon,
              decoration: const InputDecoration(labelText: 'Days', isDense: true),
              items: [3, 5, 10, 20].map((h) => DropdownMenuItem(value: h, child: Text('$h d'))).toList(),
              onChanged: (v) => onHorizonChanged(v!),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: scanning ? null : onScan,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
            child: scanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search, size: 18),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final MoverStock stock;
  final int rank;
  const _StockCard({required this.stock, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isUp = stock.dayChangePct >= 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => StockDetailScreen(symbol: stock.fullSymbol, name: stock.name),
        )),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: rank <= 3 ? AppTheme.green : AppTheme.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12,
                    color: rank <= 3 ? Colors.white : AppTheme.textSecondary,
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text(stock.symbol,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${stock.price.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '${isUp ? '+' : ''}${stock.dayChangePct.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 11, color: isUp ? AppTheme.green : AppTheme.red, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SignalPill(label: stock.technicalLabel),
                const SizedBox(height: 3),
                Text('${stock.compositeScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

