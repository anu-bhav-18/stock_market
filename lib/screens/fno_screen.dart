import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FnoScreen extends StatefulWidget {
  const FnoScreen({super.key});

  @override
  State<FnoScreen> createState() => _FnoScreenState();
}

class _FnoScreenState extends State<FnoScreen> {
  static const _indexSymbols = ['NIFTY', 'BANKNIFTY', 'FINNIFTY', 'MIDCPNIFTY'];

  String _symbol = 'NIFTY';
  String? _expiry;
  OptionsChain? _chain;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? expiry}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final chain = await ApiService.fetchOptionsChain(_symbol, expiry: expiry ?? _expiry);
      if (mounted) {
        setState(() {
          _chain = chain;
          _expiry = chain.selectedExpiry;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ F&O Signals'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _SymbolBar(
            symbols: _indexSymbols,
            selected: _symbol,
            onChanged: (s) { setState(() { _symbol = s; _expiry = null; _chain = null; }); _load(); },
          ),
        ),
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.green),
                SizedBox(height: 12),
                Text('Fetching NSE live data…', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _chain == null
                  ? const SizedBox.shrink()
                  : _ChainView(
                      chain: _chain!,
                      onExpiryChanged: (e) => _load(expiry: e),
                    ),
    );
  }
}

class _SymbolBar extends StatelessWidget {
  final List<String> symbols;
  final String selected;
  final void Function(String) onChanged;

  const _SymbolBar({required this.symbols, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: symbols.map((s) {
          final active = s == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppTheme.green : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppTheme.green : Colors.grey.shade300),
                ),
                child: Text(s,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: active ? Colors.white : AppTheme.textPrimary,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChainView extends StatelessWidget {
  final OptionsChain chain;
  final void Function(String) onExpiryChanged;

  const _ChainView({required this.chain, required this.onExpiryChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Expiry selector
        if (chain.allExpiries.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chain.allExpiries.take(6).map((e) {
                final active = e == chain.selectedExpiry;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onExpiryChanged(e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.blue.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: active ? AppTheme.blue : Colors.grey.shade300),
                      ),
                      child: Text(e,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: active ? AppTheme.blue : AppTheme.textSecondary,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 14),

        // Signal card
        _SignalCard(chain: chain),
        const SizedBox(height: 12),

        // Stats row
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Spot', value: '₹${chain.spot.toStringAsFixed(1)}')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Max Pain', value: '₹${chain.maxPain.toStringAsFixed(0)}')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'PCR',
              value: chain.pcr.toStringAsFixed(2),
              valueColor: chain.pcr > 1.2 ? AppTheme.green : chain.pcr < 0.8 ? AppTheme.red : AppTheme.textPrimary,
            )),
          ],
        ),
        const SizedBox(height: 12),

        // OI bar chart
        _OIChart(chain: chain),
        const SizedBox(height: 12),

        // Options chain table
        _ChainTable(chain: chain),
        const SizedBox(height: 24),
        const Text(
          '⚠️ Options trading involves significant risk. This is for educational purposes only.',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  final OptionsChain chain;
  const _SignalCard({required this.chain});

  Color get _directionColor {
    if (chain.direction.contains('CE')) return AppTheme.green;
    if (chain.direction.contains('PE')) return AppTheme.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _directionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                chain.direction.contains('CE')
                    ? Icons.trending_up
                    : chain.direction.contains('PE')
                        ? Icons.trending_down
                        : Icons.drag_handle,
                color: _directionColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chain.direction,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _directionColor,
                      )),
                  Text('PCR ${chain.pcr.toStringAsFixed(2)} — ${chain.pcrSignal}  |  Max Pain ₹${chain.maxPain.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCard({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: valueColor ?? AppTheme.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

class _OIChart extends StatelessWidget {
  final OptionsChain chain;
  const _OIChart({required this.chain});

  @override
  Widget build(BuildContext context) {
    final atm = chain.atmStrike;
    // Pick 10 strikes around ATM
    final sorted = [...chain.strikes]..sort((a, b) => (a.strike - atm).abs().compareTo((b.strike - atm).abs()));
    final display = sorted.take(10).toList()..sort((a, b) => a.strike.compareTo(b.strike));

    if (display.isEmpty) return const SizedBox.shrink();

    final maxOI = display.fold<double>(0, (m, s) => [m, s.ceOI.toDouble(), s.peOI.toDouble()].reduce((a, b) => a > b ? a : b));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Open Interest (ATM ± 5 strikes)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Row(children: [
              _OILegend(color: AppTheme.red, label: 'CE OI'),
              const SizedBox(width: 12),
              _OILegend(color: AppTheme.green, label: 'PE OI'),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxOI * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= display.length) return const SizedBox.shrink();
                          final strike = display[idx].strike;
                          final isAtm = strike == atm;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              strike >= 1000
                                  ? strike.toStringAsFixed(0)
                                  : strike.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isAtm ? FontWeight.w800 : FontWeight.normal,
                                color: isAtm ? AppTheme.blue : AppTheme.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: display.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(toY: e.value.ceOI.toDouble(), color: AppTheme.red.withValues(alpha: 0.8), width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                        BarChartRodData(toY: e.value.peOI.toDouble(), color: AppTheme.green.withValues(alpha: 0.8), width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OILegend extends StatelessWidget {
  final Color color;
  final String label;
  const _OILegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]);
  }
}

class _ChainTable extends StatelessWidget {
  final OptionsChain chain;
  const _ChainTable({required this.chain});

  @override
  Widget build(BuildContext context) {
    final atm = chain.atmStrike;
    return Card(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('CE OI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.red), textAlign: TextAlign.left)),
                Expanded(child: Text('CE LTP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.red), textAlign: TextAlign.center)),
                Expanded(child: Text('STRIKE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.blue), textAlign: TextAlign.center)),
                Expanded(child: Text('PE LTP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green), textAlign: TextAlign.center)),
                Expanded(child: Text('PE OI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ...chain.strikes.map((s) {
            final isAtm = s.strike == atm;
            return Container(
              color: isAtm ? AppTheme.blue.withValues(alpha: 0.06) : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Expanded(child: Text(_fmt(s.ceOI), style: const TextStyle(fontSize: 11, color: AppTheme.red))),
                  Expanded(child: Text('₹${s.ceLTP.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text(s.strike.toStringAsFixed(0),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isAtm ? AppTheme.blue : AppTheme.textPrimary),
                      textAlign: TextAlign.center)),
                  Expanded(child: Text('₹${s.peLTP.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text(_fmt(s.peOI), style: const TextStyle(fontSize: 11, color: AppTheme.green), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text('NSE data unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(error, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
