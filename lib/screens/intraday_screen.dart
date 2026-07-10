import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class IntradayScreen extends StatefulWidget {
  const IntradayScreen({super.key});

  @override
  State<IntradayScreen> createState() => _IntradayScreenState();
}

class _IntradayScreenState extends State<IntradayScreen> {
  static const _indices = [
    'Nifty Bank', 'Nifty IT', 'Nifty 50', 'Nifty Pharma',
    'Nifty Auto', 'Nifty FMCG', 'Nifty Metal',
  ];
  static const _intervals = ['5m', '15m', '30m'];

  String _index = 'Nifty Bank';
  String _interval = '15m';
  List<IntradayStock>? _results;
  bool _scanning = false;
  String? _error;
  DateTime? _lastScanned;

  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; _results = null; });
    try {
      final r = await ApiService.fetchIntradayScan(index: _index, interval: _interval);
      if (mounted) {
        setState(() {
          _results = r;
          _scanning = false;
          _lastScanned = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _scanning = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intraday Scanner'),
        actions: [
          if (_lastScanned != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Updated ${_lastScanned!.hour.toString().padLeft(2, '0')}:'
                  '${_lastScanned!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            indices: _indices,
            intervals: _intervals,
            selectedIndex: _index,
            selectedInterval: _interval,
            scanning: _scanning,
            onIndexChanged: (v) => setState(() { _index = v; _results = null; }),
            onIntervalChanged: (v) => setState(() { _interval = v; _results = null; }),
            onScan: _scan,
          ),
          if (_scanning) ...[
            const LinearProgressIndicator(color: AppTheme.green),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Fetching intraday data... this may take 30-60 seconds',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 12)),
              ),
            ),
          if (_results == null && !_scanning && _error == null)
            const Expanded(child: _EmptyState()),
          if (_results != null) ...[
            _SummaryBar(results: _results!),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _StockCard(stock: _results![i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> indices;
  final List<String> intervals;
  final String selectedIndex;
  final String selectedInterval;
  final bool scanning;
  final void Function(String) onIndexChanged;
  final void Function(String) onIntervalChanged;
  final VoidCallback onScan;

  const _FilterBar({
    required this.indices, required this.intervals,
    required this.selectedIndex, required this.selectedInterval,
    required this.scanning, required this.onIndexChanged,
    required this.onIntervalChanged, required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          // Index chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: indices.map((idx) {
                final active = idx == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onIndexChanged(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.green : AppTheme.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(idx,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppTheme.textSecondary,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Interval buttons
              ...intervals.map((iv) {
                final active = iv == selectedInterval;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onIntervalChanged(iv),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.blue.withValues(alpha: 0.1) : AppTheme.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? AppTheme.blue : Colors.transparent),
                      ),
                      child: Text(iv,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? AppTheme.blue : AppTheme.textSecondary,
                          )),
                    ),
                  ),
                );
              }),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.radar, size: 16),
                label: Text(scanning ? 'Scanning...' : 'Scan Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<IntradayStock> results;
  const _SummaryBar({required this.results});

  @override
  Widget build(BuildContext context) {
    final buyCount = results.where((s) => s.signal.contains('Buy') || s.signal.contains('Breakout')).length;
    final sellCount = results.where((s) => s.signal.contains('Sell') || s.signal.contains('Breakdown')).length;
    final neutralCount = results.length - buyCount - sellCount;

    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SummaryChip(count: buyCount, label: 'Buy', color: AppTheme.green),
          const SizedBox(width: 8),
          _SummaryChip(count: neutralCount, label: 'Neutral', color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryChip(count: sellCount, label: 'Sell', color: AppTheme.red),
          const Spacer(),
          Text('${results.length} stocks', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _SummaryChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count $label',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StockCard extends StatelessWidget {
  final IntradayStock stock;
  const _StockCard({required this.stock});

  Color get _signalColor {
    final s = stock.signal;
    if (s.contains('Strong Buy') || s.contains('Breakout')) return AppTheme.green;
    if (s.contains('Buy')) return AppTheme.green;
    if (s.contains('Strong Sell') || s.contains('Breakdown')) return AppTheme.red;
    if (s.contains('Sell')) return AppTheme.red;
    return Colors.orange;
  }

  Color get _signalBg => _signalColor.withValues(alpha: 0.1);

  @override
  Widget build(BuildContext context) {
    final isUp = stock.dayChgPct >= 0;
    final chgColor = isUp ? AppTheme.green : AppTheme.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Signal badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _signalBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(stock.signal,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _signalColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(stock.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${stock.price.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('${isUp ? '+' : ''}${stock.dayChgPct.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 11, color: chgColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  label: 'VWAP',
                  value: '₹${stock.vwap.toStringAsFixed(1)}',
                  valueColor: stock.aboveVwap ? AppTheme.green : AppTheme.red,
                  icon: stock.aboveVwap ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                const SizedBox(width: 8),
                _MiniStat(label: 'RSI', value: stock.rsi.toStringAsFixed(0),
                    valueColor: stock.rsi > 60 ? AppTheme.green : stock.rsi < 40 ? AppTheme.red : AppTheme.textPrimary),
                const SizedBox(width: 8),
                _MiniStat(
                  label: 'Vol Ratio',
                  value: '${stock.volumeRatio.toStringAsFixed(1)}x',
                  valueColor: stock.volumeRatio > 2 ? AppTheme.green : AppTheme.textPrimary,
                ),
                if (stock.orbBreakout || stock.orbBreakdown) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stock.orbBreakout
                          ? AppTheme.green.withValues(alpha: 0.15)
                          : AppTheme.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stock.orbBreakout ? 'ORB ↑' : 'ORB ↓',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: stock.orbBreakout ? AppTheme.green : AppTheme.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // OR levels bar
            const SizedBox(height: 8),
            _ORBar(price: stock.price, orHigh: stock.orHigh, orLow: stock.orLow, vwap: stock.vwap),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  const _MiniStat({required this.label, required this.value, this.valueColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        Row(
          children: [
            if (icon != null) Icon(icon, size: 10, color: valueColor),
            Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor))),
          ],
        ),
      ],
    );
  }
}

class _ORBar extends StatelessWidget {
  final double price;
  final double orHigh;
  final double orLow;
  final double vwap;
  const _ORBar({required this.price, required this.orHigh, required this.orLow, required this.vwap});

  @override
  Widget build(BuildContext context) {
    // Show opening range with current price position
    final range = orHigh - orLow;
    if (range <= 0) return const SizedBox.shrink();

    // Extend view 20% above/below OR
    final viewMin = orLow - range * 0.3;
    final viewMax = orHigh + range * 0.3;
    final viewRange = viewMax - viewMin;

    double pct(double v) => ((v - viewMin) / viewRange).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Opening Range', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: 20,
            child: Stack(
              children: [
                // Background
                Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)))),
                // OR zone
                Positioned(
                  left: pct(orLow) * w,
                  width: (pct(orHigh) - pct(orLow)) * w,
                  top: 0, bottom: 0,
                  child: Container(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                // VWAP line
                Positioned(
                  left: pct(vwap) * w - 1,
                  width: 2, top: 0, bottom: 0,
                  child: Container(color: AppTheme.blue.withValues(alpha: 0.6)),
                ),
                // Price marker
                Positioned(
                  left: (pct(price) * w - 4).clamp(0, w - 8),
                  width: 8, top: 4, bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: price > orHigh ? AppTheme.green : price < orLow ? AppTheme.red : Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('L ${orLow.toStringAsFixed(0)}', style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)),
            Text('H ${orHigh.toStringAsFixed(0)}', style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 56, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Select index + interval, then tap Scan',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          SizedBox(height: 6),
          Text('Uses VWAP, ORB, RSI and Volume to rank stocks',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          SizedBox(height: 4),
          Text('Works during market hours (9:15 AM - 3:30 PM IST)',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
