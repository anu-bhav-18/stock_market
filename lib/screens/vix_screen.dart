import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class VixScreen extends StatefulWidget {
  const VixScreen({super.key});
  @override
  State<VixScreen> createState() => _VixScreenState();
}

class _VixScreenState extends State<VixScreen> {
  IndiaVix? _vix;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final v = await ApiService.fetchVix();
      if (mounted) setState(() { _vix = v; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _vixColor(String c) {
    if (c == 'green') return AppTheme.green;
    if (c == 'red') return AppTheme.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('India VIX'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ])))
              : _vix == null ? const SizedBox.shrink()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final vix = _vix!;
    final color = _vixColor(vix.color);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main VIX card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('India VIX', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(vix.current.toStringAsFixed(2),
                  style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: color)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(vix.change >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: vix.change >= 0 ? AppTheme.red : AppTheme.green, size: 20),
                Text(
                  '${vix.change >= 0 ? '+' : ''}${vix.change.toStringAsFixed(2)} '
                  '(${vix.changePct >= 0 ? '+' : ''}${vix.changePct.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: vix.change >= 0 ? AppTheme.red : AppTheme.green,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(vix.sentiment,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              const SizedBox(height: 10),
              Text(vix.note,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // VIX gauge zones
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VIX Zones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),
              _VixZone(range: '< 15', label: 'Low Fear', desc: 'Cheap options, good time to buy calls/puts', color: AppTheme.green, current: vix.current, lo: 0, hi: 15),
              _VixZone(range: '15–20', label: 'Moderate', desc: 'Normal market conditions', color: Colors.orange, current: vix.current, lo: 15, hi: 20),
              _VixZone(range: '20–25', label: 'Elevated', desc: 'Market nervous — buy puts for protection', color: Colors.deepOrange, current: vix.current, lo: 20, hi: 25),
              _VixZone(range: '> 25', label: 'High Fear', desc: 'Panic — often a contrarian buy signal', color: AppTheme.red, current: vix.current, lo: 25, hi: 100),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // 20-day chart
        if (vix.history.length >= 5)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('20-Day VIX Chart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    minY: vix.history.map((p) => p.value).reduce((a, b) => a < b ? a : b) - 1,
                    maxY: vix.history.map((p) => p.value).reduce((a, b) => a > b ? a : b) + 1,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, interval: 5,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= vix.history.length) return const SizedBox.shrink();
                          final parts = vix.history[idx].date.split('-');
                          return Padding(padding: const EdgeInsets.only(top: 4),
                              child: Text('${parts[2]}/${parts[1]}',
                                  style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)));
                        },
                      )),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30,
                        getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: vix.history.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                            .toList(),
                        isCurved: true,
                        color: color,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
                      ),
                    ],
                  )),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 16),

        // Trading tips
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How to use VIX', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              _Tip(icon: Icons.trending_down, color: AppTheme.green,
                  text: 'Low VIX (<15): Options premiums are cheap — good time to buy straddles or directional options.'),
              _Tip(icon: Icons.trending_up, color: AppTheme.red,
                  text: 'High VIX (>25): Sell options (collect premium) or buy the dip — fear is often overdone.'),
              _Tip(icon: Icons.show_chart, color: AppTheme.blue,
                  text: 'VIX spikes usually coincide with market bottoms. Watch for reversal when VIX peaks.'),
              _Tip(icon: Icons.shield_outlined, color: Colors.orange,
                  text: 'Rising VIX + falling market = hedges working. Don\'t panic-sell at VIX peaks.'),
            ]),
          ),
        ),
      ],
    );
  }
}

class _VixZone extends StatelessWidget {
  final String range, label, desc;
  final Color color;
  final double current, lo, hi;
  const _VixZone({required this.range, required this.label, required this.desc,
      required this.color, required this.current, required this.lo, required this.hi});

  bool get isActive => current >= lo && current < hi;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: isActive ? Border.all(color: color.withValues(alpha: 0.4)) : null,
    ),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$range  ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
              color: isActive ? color : AppTheme.textPrimary)),
          if (isActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
        Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ])),
    ]),
  );
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Tip({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.4))),
    ]),
  );
}
