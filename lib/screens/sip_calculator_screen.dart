import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class SipCalculatorScreen extends StatefulWidget {
  const SipCalculatorScreen({super.key});
  @override
  State<SipCalculatorScreen> createState() => _SipCalculatorScreenState();
}

class _SipCalculatorScreenState extends State<SipCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _monthlyCtrl  = TextEditingController(text: '5000');
  final _rateCtrl     = TextEditingController(text: '12');
  final _yearsCtrl    = TextEditingController(text: '10');
  final _lumpsumCtrl  = TextEditingController(text: '0');
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _monthlyCtrl.dispose(); _rateCtrl.dispose();
    _yearsCtrl.dispose(); _lumpsumCtrl.dispose();
    super.dispose();
  }

  double get _monthly => double.tryParse(_monthlyCtrl.text) ?? 0;
  double get _rate    => double.tryParse(_rateCtrl.text) ?? 12;
  int    get _years   => int.tryParse(_yearsCtrl.text) ?? 10;
  double get _lumpsum => double.tryParse(_lumpsumCtrl.text) ?? 0;

  // SIP future value
  double get _sipFV {
    final r = _rate / 100 / 12;
    final n = _years * 12;
    if (r == 0) return _monthly * n;
    return _monthly * ((pow(1 + r, n) - 1) / r) * (1 + r);
  }

  // Lumpsum future value
  double get _lumpsumFV {
    return _lumpsum * pow(1 + _rate / 100, _years);
  }

  double get _totalFV     => _sipFV + _lumpsumFV;
  double get _invested    => _monthly * _years * 12 + _lumpsum;
  double get _wealthGain  => _totalFV - _invested;

  // Yearly breakdown for chart
  List<Map<String, double>> get _yearly {
    final r = _rate / 100 / 12;
    final rows = <Map<String, double>>[];
    for (int y = 1; y <= _years; y++) {
      final n = y * 12;
      final sip = r == 0
          ? _monthly * n
          : _monthly * ((pow(1 + r, n) - 1) / r) * (1 + r);
      final ls = _lumpsum * pow(1 + _rate / 100, y);
      final inv = _monthly * n + _lumpsum;
      rows.add({'year': y.toDouble(), 'invested': inv, 'value': sip + ls});
    }
    return rows;
  }

  String _fmt(double v) {
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)} L';
    if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)} K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIP Calculator'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Calculator'), Tab(text: 'Projection')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildCalculator(),
        _buildProjection(),
      ]),
    );
  }

  Widget _buildCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Input card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _InputRow(label: 'Monthly SIP (₹)', ctrl: _monthlyCtrl,
                  prefix: '₹', onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              _InputRow(label: 'Expected Return (%/yr)', ctrl: _rateCtrl,
                  suffix: '%', onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              _InputRow(label: 'Investment Period (Years)', ctrl: _yearsCtrl,
                  suffix: 'yr', onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              _InputRow(label: 'Lumpsum (₹, optional)', ctrl: _lumpsumCtrl,
                  prefix: '₹', onChanged: (_) => setState(() {})),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Result cards
        Row(children: [
          Expanded(child: _ResultCard(
            label: 'Invested', value: _fmt(_invested), color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _ResultCard(
            label: 'Returns', value: _fmt(_wealthGain), color: AppTheme.green)),
        ]),
        const SizedBox(height: 8),
        _ResultCard(
          label: 'Total Value after $_years years',
          value: _fmt(_totalFV),
          color: AppTheme.blue,
          large: true,
        ),
        const SizedBox(height: 12),

        // Donut-style summary bar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              const Text('Invested vs Returns', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Row(children: [
                    Flexible(
                      flex: (_invested / _totalFV * 100).round().clamp(1, 99),
                      child: Container(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    ),
                    Flexible(
                      flex: (_wealthGain / _totalFV * 100).round().clamp(1, 99),
                      child: Container(color: AppTheme.green),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _LegendDot(color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    label: 'Invested ${(_invested / _totalFV * 100).toStringAsFixed(1)}%'),
                const SizedBox(width: 16),
                _LegendDot(color: AppTheme.green,
                    label: 'Returns ${(_wealthGain / _totalFV * 100).toStringAsFixed(1)}%'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Preset rate comparison
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate Comparison (same SIP)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                ...[8.0, 10.0, 12.0, 15.0, 18.0].map((r) {
                  final mr = r / 100 / 12;
                  final n  = _years * 12;
                  final fv = mr == 0 ? _monthly * n
                      : _monthly * ((pow(1 + mr, n) - 1) / mr) * (1 + mr);
                  final isSelected = r == _rate;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(width: 50, child: Text('$r%',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.blue : AppTheme.textSecondary,
                              fontSize: 12))),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fv / (_monthly * ((pow(1 + 18/100/12, n) - 1) / (18/100/12)) * (1 + 18/100/12)),
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSelected ? AppTheme.blue : AppTheme.textSecondary.withValues(alpha: 0.4)),
                        ),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 70, child: Text(_fmt(fv),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.blue : AppTheme.textPrimary),
                          textAlign: TextAlign.right)),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProjection() {
    final rows = _yearly;
    if (rows.isEmpty) return const Center(child: Text('Enter values to see projection'));
    final maxVal = rows.last['value']!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Year-wise Growth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                ...rows.map((r) {
                  final year   = r['year']!.toInt();
                  final val    = r['value']!;
                  final inv    = r['invested']!;
                  final pct    = val / maxVal;
                  final invPct = inv / maxVal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        SizedBox(width: 40, child: Text('Y$year',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                        Expanded(child: Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: invPct.clamp(0.0, 1.0),
                              minHeight: 20,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 20,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.green.withValues(alpha: 0.5)),
                            ),
                          ),
                        ])),
                        const SizedBox(width: 8),
                        SizedBox(width: 72, child: Text(_fmt(val),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green),
                            textAlign: TextAlign.right)),
                      ]),
                    ]),
                  );
                }),
                const SizedBox(height: 4),
                Row(children: [
                  _LegendDot(color: AppTheme.textSecondary, label: 'Invested'),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppTheme.green, label: 'Total Value'),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
              children: [
                TableRow(children: [
                  _TH('Year'), _TH('Invested'), _TH('Value'), _TH('Gain'),
                ]),
                ...rows.where((r) => r['year']!.toInt() % 2 == 0 || r['year']!.toInt() == 1 || r['year']!.toInt() == _years).map((r) {
                  final gain = r['value']! - r['invested']!;
                  return TableRow(children: [
                    _TD('Y${r['year']!.toInt()}'),
                    _TD(_fmt(r['invested']!)),
                    _TD(_fmt(r['value']!), bold: true),
                    _TD(_fmt(gain), color: AppTheme.green),
                  ]);
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('⚠ Returns are estimated. Actual returns vary with market conditions.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? prefix, suffix;
  final ValueChanged<String> onChanged;
  const _InputRow({required this.label, required this.ctrl, this.prefix, this.suffix, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool large;
  const _ResultCard({required this.label, required this.value, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
            fontSize: large ? 22 : 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  ]);
}

Widget _TH(String t) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
);

Widget _TD(String t, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Text(t, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: color)),
);
