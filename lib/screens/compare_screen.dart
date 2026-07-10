import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();
  Quote? _q1, _q2;
  SignalResult? _s1, _s2;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctrl1.dispose(); _ctrl2.dispose(); super.dispose(); }

  String _sym(String v) {
    final s = v.trim().toUpperCase();
    return s.endsWith('.NS') ? s : '$s.NS';
  }

  Future<void> _compare() async {
    final sym1 = _ctrl1.text.trim();
    final sym2 = _ctrl2.text.trim();
    if (sym1.isEmpty || sym2.isEmpty) return;
    setState(() { _loading = true; _error = null; _q1 = null; _q2 = null; _s1 = null; _s2 = null; });
    try {
      await Future.wait([
        ApiService.fetchQuote(_sym(sym1)).then((v) { _q1 = v; }).catchError((_) {}),
        ApiService.fetchQuote(_sym(sym2)).then((v) { _q2 = v; }).catchError((_) {}),
        ApiService.fetchSignal(_sym(sym1)).then((v) { _s1 = v; }).catchError((_) {}),
        ApiService.fetchSignal(_sym(sym2)).then((v) { _s2 = v; }).catchError((_) {}),
      ]);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _q1 != null || _q2 != null;
    final sym1 = _ctrl1.text.trim().toUpperCase().replaceAll('.NS', '');
    final sym2 = _ctrl2.text.trim().toUpperCase().replaceAll('.NS', '');

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Stocks')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl1,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Stock 1', hintText: 'e.g. RELIANCE', isDense: true),
              onSubmitted: (_) => _compare(),
            )),
            const SizedBox(width: 12),
            const Icon(Icons.compare_arrows_rounded, color: AppTheme.blue),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _ctrl2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Stock 2', hintText: 'e.g. TCS', isDense: true),
              onSubmitted: (_) => _compare(),
            )),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _loading ? null : _compare,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13)),
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 18),
            ),
          ]),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 12))),
        if (!hasData && !_loading)
          const Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.compare_arrows_rounded, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Enter two stock symbols to compare', style: TextStyle(color: AppTheme.textSecondary)),
          ]))),
        if (hasData)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Header row
                _HeaderRow(sym1: sym1, sym2: sym2),
                const SizedBox(height: 12),
                // Price
                _CompareRow(
                  label: 'Price',
                  val1: _q1 != null ? '₹${_q1!.price.toStringAsFixed(2)}' : '-',
                  val2: _q2 != null ? '₹${_q2!.price.toStringAsFixed(2)}' : '-',
                ),
                _CompareRow(
                  label: 'Day Change',
                  val1: _q1 != null ? '${_q1!.changePct >= 0 ? '+' : ''}${_q1!.changePct.toStringAsFixed(2)}%' : '-',
                  val2: _q2 != null ? '${_q2!.changePct >= 0 ? '+' : ''}${_q2!.changePct.toStringAsFixed(2)}%' : '-',
                  color1: _q1 != null ? (_q1!.changePct >= 0 ? AppTheme.green : AppTheme.red) : null,
                  color2: _q2 != null ? (_q2!.changePct >= 0 ? AppTheme.green : AppTheme.red) : null,
                  highlight: _highlightChange(_q1?.changePct, _q2?.changePct),
                ),
                const Divider(height: 20),
                _CompareRow(
                  label: 'Signal',
                  val1: _s1?.technical.label ?? '-',
                  val2: _s2?.technical.label ?? '-',
                  color1: _signalColor(_s1?.technical.label),
                  color2: _signalColor(_s2?.technical.label),
                ),
                _CompareRow(
                  label: 'Score',
                  val1: _s1 != null ? '${_s1!.compositeScore.toStringAsFixed(0)}/100' : '-',
                  val2: _s2 != null ? '${_s2!.compositeScore.toStringAsFixed(0)}/100' : '-',
                  highlight: _highlightScore(_s1?.compositeScore, _s2?.compositeScore),
                ),
                _CompareRow(
                  label: 'ML Prob Up',
                  val1: _s1?.ml.probabilityUp != null ? '${(_s1!.ml.probabilityUp! * 100).toStringAsFixed(1)}%' : 'N/A',
                  val2: _s2?.ml.probabilityUp != null ? '${(_s2!.ml.probabilityUp! * 100).toStringAsFixed(1)}%' : 'N/A',
                  highlight: _highlightProb(_s1?.ml.probabilityUp, _s2?.ml.probabilityUp),
                ),
                const Divider(height: 20),
                if (_s1 != null || _s2 != null) ...[
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('Key Signals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SignalsList(reasons: _s1?.technical.reasons ?? [])),
                    const SizedBox(width: 12),
                    Expanded(child: _SignalsList(reasons: _s2?.technical.reasons ?? [])),
                  ]),
                ],
                const SizedBox(height: 12),
                const Text('⚠ Educational only. Not financial advice.',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
      ]),
    );
  }

  int _highlightChange(double? a, double? b) {
    if (a == null || b == null) return 0;
    return a > b ? 1 : b > a ? 2 : 0;
  }

  int _highlightScore(double? a, double? b) {
    if (a == null || b == null) return 0;
    return a > b ? 1 : b > a ? 2 : 0;
  }

  int _highlightProb(double? a, double? b) {
    if (a == null || b == null) return 0;
    return a > b ? 1 : b > a ? 2 : 0;
  }

  Color? _signalColor(String? label) {
    if (label == null) return null;
    if (label.contains('Bullish') || label.contains('Strong Buy')) return AppTheme.green;
    if (label.contains('Bearish') || label.contains('Strong Sell')) return AppTheme.red;
    return Colors.orange;
  }
}

class _HeaderRow extends StatelessWidget {
  final String sym1, sym2;
  const _HeaderRow({required this.sym1, required this.sym2});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(sym1.isEmpty ? 'Stock 1' : sym1,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.green)),
    )),
    const SizedBox(width: 8),
    const Text('vs', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
    const SizedBox(width: 8),
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppTheme.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(sym2.isEmpty ? 'Stock 2' : sym2,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.blue)),
    )),
  ]);
}

class _CompareRow extends StatelessWidget {
  final String label, val1, val2;
  final Color? color1, color2;
  final int highlight; // 1 = left wins, 2 = right wins, 0 = neutral
  const _CompareRow({required this.label, required this.val1, required this.val2,
      this.color1, this.color2, this.highlight = 0});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight == 1 ? AppTheme.green.withValues(alpha: 0.07) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        child: Text(val1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color1)),
      )),
      SizedBox(width: 80, child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          textAlign: TextAlign.center)),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight == 2 ? AppTheme.blue.withValues(alpha: 0.07) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(val2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color2)),
      )),
    ]),
  );
}

class _SignalsList extends StatelessWidget {
  final List<String> reasons;
  const _SignalsList({required this.reasons});

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const Text('-', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: reasons.take(4).map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 11, color: AppTheme.green)),
          Expanded(child: Text(r, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      )).toList(),
    );
  }
}
