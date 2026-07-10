import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class MarketBreadthScreen extends StatefulWidget {
  const MarketBreadthScreen({super.key});
  @override
  State<MarketBreadthScreen> createState() => _MarketBreadthScreenState();
}

class _MarketBreadthScreenState extends State<MarketBreadthScreen> {
  static const _indices = ['Nifty 50', 'Nifty Bank', 'Nifty IT', 'Nifty Next 50', 'Nifty Midcap 50'];
  String _index = 'Nifty 50';
  MarketBreadth? _breadth;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final b = await ApiService.fetchMarketBreadth(index: _index);
      if (mounted) setState(() { _breadth = b; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Breadth'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Index selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _indices.map((idx) {
                final active = idx == _index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { if (idx != _index) setState(() => _index = idx); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.green : AppTheme.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: active ? AppTheme.green : Colors.grey.shade300),
                      ),
                      child: Text(idx, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppTheme.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(color: AppTheme.green),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: AppTheme.red))),
        if (_breadth != null)
          Expanded(child: _BreadthView(breadth: _breadth!, index: _index)),
      ]),
    );
  }
}

class _BreadthView extends StatelessWidget {
  final MarketBreadth breadth;
  final String index;
  const _BreadthView({required this.breadth, required this.index});

  @override
  Widget build(BuildContext context) {
    final adRatio = breadth.advanceDeclineRatio;
    final mood = adRatio > 1.5 ? 'Bullish' : adRatio < 0.7 ? 'Bearish' : 'Neutral';
    final moodColor = adRatio > 1.5 ? AppTheme.green : adRatio < 0.7 ? AppTheme.red : Colors.orange;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Market Mood card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(index, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Row(children: [
                Text('Market Mood: ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(mood, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: moodColor)),
              ]),
              const SizedBox(height: 12),
              Text('Avg Day Change: ${breadth.averageChangePct >= 0 ? '+' : ''}${breadth.averageChangePct.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 13, color: breadth.averageChangePct >= 0 ? AppTheme.green : AppTheme.red,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Advance / Decline
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Advance / Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 14),
              _ADBar(advancing: breadth.advancing, declining: breadth.declining,
                  unchanged: breadth.unchanged, total: breadth.total),
              const SizedBox(height: 14),
              Row(children: [
                _ADStat(label: 'Advancing', value: '${breadth.advancing}', color: AppTheme.green),
                _ADStat(label: 'Declining', value: '${breadth.declining}', color: AppTheme.red),
                _ADStat(label: 'Unchanged', value: '${breadth.unchanged}', color: Colors.orange),
                _ADStat(label: 'A/D Ratio', value: adRatio.toStringAsFixed(2), color: moodColor),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // % Above SMA50
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('% Stocks Above SMA-50', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${breadth.pctAboveSma50.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                          color: breadth.pctAboveSma50 > 60 ? AppTheme.green
                              : breadth.pctAboveSma50 < 40 ? AppTheme.red : Colors.orange)),
                  Text(
                    breadth.pctAboveSma50 > 70 ? 'Strong uptrend — most stocks healthy'
                        : breadth.pctAboveSma50 > 50 ? 'Moderate breadth — market holding up'
                        : breadth.pctAboveSma50 > 30 ? 'Weak breadth — caution advised'
                        : 'Very weak — most stocks below trend',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ])),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: breadth.pctAboveSma50 / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    breadth.pctAboveSma50 > 60 ? AppTheme.green
                        : breadth.pctAboveSma50 < 40 ? AppTheme.red : Colors.orange,
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Interpretation
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How to read this', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              _Tip(icon: Icons.trending_up, color: AppTheme.green,
                  text: 'A/D Ratio > 1.5 = broad market rally. High conviction for longs.'),
              _Tip(icon: Icons.trending_down, color: AppTheme.red,
                  text: 'A/D Ratio < 0.7 = broad sell-off. Prefer cash or hedges.'),
              _Tip(icon: Icons.show_chart, color: AppTheme.blue,
                  text: '% Above SMA50 > 70% = healthy trend. < 30% = market stress.'),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ADBar extends StatelessWidget {
  final int advancing, declining, unchanged, total;
  const _ADBar({required this.advancing, required this.declining, required this.unchanged, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final adPct = advancing / total;
    final dcPct = declining / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 20,
        child: Row(children: [
          Flexible(flex: (adPct * 100).round(), child: Container(color: AppTheme.green)),
          Flexible(flex: ((1 - adPct - dcPct) * 100).round().clamp(0, 100), child: Container(color: Colors.orange.shade200)),
          Flexible(flex: (dcPct * 100).round(), child: Container(color: AppTheme.red)),
        ]),
      ),
    );
  }
}

class _ADStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ADStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
  ]));
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
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
    ]),
  );
}
