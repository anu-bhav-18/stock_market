import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';
import '../theme.dart';
import 'stock_detail_screen.dart';

class MarketTrendsScreen extends StatefulWidget {
  const MarketTrendsScreen({super.key});
  @override
  State<MarketTrendsScreen> createState() => _MarketTrendsScreenState();
}

class _MarketTrendsScreenState extends State<MarketTrendsScreen>
    with SingleTickerProviderStateMixin {
  static const _indices = ['Nifty 50', 'Nifty Bank', 'Nifty IT', 'Nifty Next 50', 'Nifty Midcap 50'];
  String _index = 'Nifty 50';
  String _period = '1wk';
  MarketTrends? _trends;
  bool _loading = false;
  String? _error;
  late TabController _tabs;

  // Gemini AI outlook
  String? _aiOutlook;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _aiOutlook = null; });
    try {
      final t = await ApiService.fetchMarketTrends(index: _index, period: _period);
      if (mounted) setState(() { _trends = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _getAiOutlook() async {
    if (_trends == null) return;
    setState(() { _aiLoading = true; _aiOutlook = null; });
    try {
      await GeminiService.init();
      GeminiService.reset();
      final t = _trends!;
      final gainerList = t.gainers.take(5).map((s) => '${s.symbol}: +${s.returnPct.toStringAsFixed(2)}%').join(', ');
      final loserList  = t.losers.take(5).map((s) => '${s.symbol}: ${s.returnPct.toStringAsFixed(2)}%').join(', ');
      final periodLabel = _period == '1wk' ? 'weekly' : 'monthly';
      final prompt = '''
You are a senior Indian market analyst. Here is the $periodLabel performance summary for ${t.index}:

- Average return: ${t.avgReturnPct >= 0 ? '+' : ''}${t.avgReturnPct.toStringAsFixed(2)}%
- Top gainers: $gainerList
- Top losers: $loserList

Based on this $periodLabel performance, provide:
1. What these moves suggest about the current market theme/trend
2. Sectors or stocks showing momentum to watch next week
3. Stocks that may recover from losses (if any) vs those to avoid
4. One key risk factor to watch

Keep it under 8 lines, practical for an Indian retail trader. No disclaimers.''';
      final result = await GeminiService.send(prompt);
      if (mounted) setState(() { _aiOutlook = result; _aiLoading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _aiOutlook = 'Could not get AI outlook: ${e.toString().substring(0, 60)}';
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Trends'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Gainers'),
            Tab(text: 'Losers'),
            Tab(text: 'AI Outlook'),
          ],
        ),
      ),
      body: Column(children: [
        // Filters row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            // Period toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                _PeriodBtn(label: 'Week', value: '1wk', selected: _period,
                    onTap: () { setState(() { _period = '1wk'; _trends = null; }); _load(); }),
                _PeriodBtn(label: 'Month', value: '1mo', selected: _period,
                    onTap: () { setState(() { _period = '1mo'; _trends = null; }); _load(); }),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _indices.map((idx) {
                    final active = idx == _index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () { if (idx != _index) { setState(() { _index = idx; _trends = null; }); _load(); } },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? AppTheme.green : AppTheme.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active ? AppTheme.green : Colors.grey.shade300),
                          ),
                          child: Text(idx, style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppTheme.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(color: AppTheme.green),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 12))),
        if (_trends != null) ...[
          // Summary bar
          Container(
            color: AppTheme.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text(_trends!.index, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Avg: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('${_trends!.avgReturnPct >= 0 ? '+' : ''}${_trends!.avgReturnPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: _trends!.avgReturnPct >= 0 ? AppTheme.green : AppTheme.red)),
              const SizedBox(width: 12),
              Text('${_trends!.total} stocks', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _StockList(stocks: _trends!.gainers, isGainer: true),
                _StockList(stocks: _trends!.losers, isGainer: false),
                _AiOutlookTab(
                  outlook: _aiOutlook,
                  loading: _aiLoading,
                  onGenerate: _getAiOutlook,
                  trends: _trends!,
                  period: _period,
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label, value, selected;
  final VoidCallback onTap;
  const _PeriodBtn({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.green : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  final List<TrendStock> stocks;
  final bool isGainer;
  const _StockList({required this.stocks, required this.isGainer});

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: stocks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final s = stocks[i];
        final color = isGainer ? AppTheme.green : AppTheme.red;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
          title: Row(children: [
            Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(child: Text(s.name,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              Text('₹${s.startPrice.toStringAsFixed(1)} → ₹${s.endPrice.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              Text('H: ₹${s.periodHigh.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ]),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${s.returnPct >= 0 ? '+' : ''}${s.returnPct.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => StockDetailScreen(symbol: '${s.symbol}.NS', name: s.name))),
        );
      },
    );
  }
}

class _AiOutlookTab extends StatelessWidget {
  final String? outlook;
  final bool loading;
  final VoidCallback onGenerate;
  final MarketTrends trends;
  final String period;
  const _AiOutlookTab({
    required this.outlook, required this.loading,
    required this.onGenerate, required this.trends, required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Quick stats for context
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${period == '1wk' ? 'Weekly' : 'Monthly'} Summary — ${trends.index}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                _StatBox(label: 'Avg Return', value: '${trends.avgReturnPct >= 0 ? '+' : ''}${trends.avgReturnPct.toStringAsFixed(2)}%',
                    color: trends.avgReturnPct >= 0 ? AppTheme.green : AppTheme.red),
                const SizedBox(width: 8),
                _StatBox(label: 'Gainers', value: '${trends.gainers.length}', color: AppTheme.green),
                const SizedBox(width: 8),
                _StatBox(label: 'Losers', value: '${trends.losers.length}', color: AppTheme.red),
              ]),
              if (trends.gainers.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Top Gainer', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                Text('${trends.gainers.first.symbol}  +${trends.gainers.first.returnPct.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.green)),
              ],
              if (trends.losers.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Top Loser', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                Text('${trends.losers.first.symbol}  ${trends.losers.first.returnPct.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.red)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // AI Outlook card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: AppTheme.blue, size: 20),
                const SizedBox(width: 8),
                const Text('Gemini AI Market Outlook',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.blue)),
              ]),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(children: [
                    CircularProgressIndicator(color: AppTheme.blue),
                    SizedBox(height: 10),
                    Text('Gemini is analyzing the data...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ]),
                ))
              else if (outlook != null) ...[
                Text(outlook!, style: const TextStyle(fontSize: 13, height: 1.6)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Regenerate', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.blue),
                  ),
                ),
              ] else ...[
                const Text(
                  'Get an AI-powered analysis of this period\'s market performance, momentum themes, and what to watch next.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.psychology_rounded, size: 18),
                    label: const Text('Generate AI Outlook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Text('⚠ AI analysis is for educational purposes only. Not investment advice.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ]),
    ),
  );
}
