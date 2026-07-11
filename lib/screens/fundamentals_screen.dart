import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FundamentalsScreen extends StatefulWidget {
  final String symbol;
  final String name;
  const FundamentalsScreen({super.key, required this.symbol, required this.name});

  @override
  State<FundamentalsScreen> createState() => _FundamentalsScreenState();
}

class _FundamentalsScreenState extends State<FundamentalsScreen> {
  StockFundamentals? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiService.fetchFundamentals(widget.symbol);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtCap(double? v) {
    if (v == null) return 'N/A';
    if (v >= 1e12) return '₹${(v/1e12).toStringAsFixed(2)}T';
    if (v >= 1e9)  return '₹${(v/1e9).toStringAsFixed(2)}B';
    if (v >= 1e7)  return '₹${(v/1e7).toStringAsFixed(2)} Cr';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _fmtNum(double? v, {String suffix = '', int decimals = 2, bool pct = false}) {
    if (v == null) return 'N/A';
    final val = pct ? v * 100 : v;
    return '${val.toStringAsFixed(decimals)}${pct ? '%' : suffix}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ])))
              : _data == null ? const SizedBox.shrink()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sector / Industry
        if (d.sector.isNotEmpty || d.industry.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              if (d.sector.isNotEmpty) _Tag(d.sector, AppTheme.blue),
              if (d.industry.isNotEmpty) ...[const SizedBox(width: 8), _Tag(d.industry, Colors.purple)],
            ]),
          ),

        // Valuation
        _Section('Valuation'),
        _Row2('P/E Ratio', _fmtNum(d.peRatio), 'Forward P/E', _fmtNum(d.forwardPe)),
        _Row2('P/B Ratio', _fmtNum(d.pbRatio), 'Market Cap', _fmtCap(d.marketCap)),
        _Row2('EPS (TTM)', _fmtNum(d.eps, suffix: ' ₹', decimals: 2), 'Forward EPS', _fmtNum(d.forwardEps, suffix: ' ₹', decimals: 2)),
        _Row2('Dividend Yield', _fmtNum(d.dividendYield, pct: true), 'Beta', _fmtNum(d.beta)),
        const SizedBox(height: 4),

        _Section('Financials'),
        _Row2('ROE', _fmtNum(d.roe, pct: true), 'Debt/Equity', _fmtNum(d.debtToEquity)),
        _Row2('Revenue Growth', _fmtNum(d.revenueGrowth, pct: true), 'Profit Margin', _fmtNum(d.profitMargin, pct: true)),
        const SizedBox(height: 4),

        _Section('Price Levels'),
        _Row2('52W High', d.high52w != null ? '₹${d.high52w!.toStringAsFixed(2)}' : 'N/A',
              '52W Low', d.low52w != null ? '₹${d.low52w!.toStringAsFixed(2)}' : 'N/A'),
        _Row2('VWAP (20d)', d.vwap20d != null ? '₹${d.vwap20d!.toStringAsFixed(2)}' : 'N/A',
              'Avg Volume', d.avgVolume != null ? _fmtVol(d.avgVolume!) : 'N/A'),
        const SizedBox(height: 4),

        // 52-week range bar
        if (d.high52w != null && d.low52w != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('52-Week Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('₹${d.low52w!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.red)),
                  const Spacer(),
                  Text('₹${d.high52w!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.green)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: d.vwap20d != null
                        ? ((d.vwap20d! - d.low52w!) / (d.high52w! - d.low52w!)).clamp(0.0, 1.0)
                        : 0.5,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blue),
                  ),
                ),
                if (d.vwap20d != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('VWAP: ₹${d.vwap20d!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.blue)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Fibonacci levels
        if (d.fibonacci.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fibonacci Retracement (52W)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Key support & resistance levels based on 52-week range',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                ...[
                  ('0% (Low)', '0', AppTheme.red),
                  ('23.6%', '23.6', Colors.redAccent),
                  ('38.2%', '38.2', Colors.orange),
                  ('50% (Mid)', '50', Colors.amber),
                  ('61.8% (Golden)', '61.8', AppTheme.green),
                  ('78.6%', '78.6', Colors.teal),
                  ('100% (High)', '100', AppTheme.blue),
                ].map((item) {
                  final label = item.$1;
                  final key   = item.$2;
                  final color = item.$3;
                  final val   = d.fibonacci[key];
                  if (val == null) return const SizedBox.shrink();
                  final isVwap = d.vwap20d != null && (val - d.vwap20d!).abs() < (d.high52w! - d.low52w!) * 0.03;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(width: 4, height: 20, color: color, margin: const EdgeInsets.only(right: 10)),
                      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (isVwap) Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                        child: const Text('≈ VWAP', style: TextStyle(fontSize: 8, color: AppTheme.blue, fontWeight: FontWeight.w700)),
                      ),
                      Text('₹${val.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                    ]),
                  );
                }),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Valuation interpretation
        if (d.peRatio != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Valuation Signal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                ..._valuationInsights(d),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        const Text('⚠ Fundamental data from Yahoo Finance. Verify before trading.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }

  List<Widget> _valuationInsights(StockFundamentals d) {
    final insights = <Widget>[];
    if (d.peRatio != null) {
      final pe = d.peRatio!;
      final color = pe < 15 ? AppTheme.green : pe < 25 ? Colors.orange : AppTheme.red;
      final label = pe < 15 ? 'Undervalued' : pe < 25 ? 'Fairly Valued' : 'Expensive';
      insights.add(_Insight(icon: Icons.price_check, color: color,
          text: 'P/E ${pe.toStringAsFixed(1)}: $label (Nifty avg ~22x)'));
    }
    if (d.pbRatio != null) {
      final pb = d.pbRatio!;
      final color = pb < 1.5 ? AppTheme.green : pb < 3 ? Colors.orange : AppTheme.red;
      insights.add(_Insight(icon: Icons.book_outlined, color: color,
          text: 'P/B ${pb.toStringAsFixed(2)}x — ${pb < 1 ? 'Trading below book value' : pb < 3 ? 'Reasonable book multiple' : 'High premium over book value'}'));
    }
    if (d.roe != null) {
      final roe = d.roe! * 100;
      final color = roe > 15 ? AppTheme.green : roe > 8 ? Colors.orange : AppTheme.red;
      insights.add(_Insight(icon: Icons.percent, color: color,
          text: 'ROE ${roe.toStringAsFixed(1)}%: ${roe > 15 ? 'Excellent capital efficiency' : roe > 8 ? 'Average returns' : 'Poor capital efficiency'}'));
    }
    if (d.debtToEquity != null) {
      final de = d.debtToEquity!;
      final color = de < 0.5 ? AppTheme.green : de < 1.5 ? Colors.orange : AppTheme.red;
      insights.add(_Insight(icon: Icons.account_balance, color: color,
          text: 'D/E ${de.toStringAsFixed(2)}: ${de < 0.5 ? 'Low debt — strong balance sheet' : de < 1.5 ? 'Moderate leverage' : 'High debt — risky'}'));
    }
    if (insights.isEmpty) {
      insights.add(const Text('Insufficient data for valuation analysis.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)));
    }
    return insights;
  }

  String _fmtVol(double v) {
    if (v >= 1e7) return '${(v/1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '${(v/1e5).toStringAsFixed(2)} L';
    if (v >= 1e3) return '${(v/1e3).toStringAsFixed(1)} K';
    return v.toStringAsFixed(0);
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, letterSpacing: 1.2)),
  );
}

class _Row2 extends StatelessWidget {
  final String l1, v1, l2, v2;
  const _Row2(this.l1, this.v1, this.l2, this.v2);
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l1, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(v1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ])),
        Container(width: 1, height: 32, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l2, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(v2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ])),
      ]),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _Insight extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
    ]),
  );
}
