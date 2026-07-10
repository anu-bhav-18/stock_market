import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ExpectedReturnScreen extends StatefulWidget {
  const ExpectedReturnScreen({super.key});

  @override
  State<ExpectedReturnScreen> createState() => _ExpectedReturnScreenState();
}

class _ExpectedReturnScreenState extends State<ExpectedReturnScreen> {
  List<Stock> _stocks = [];
  Stock? _selected;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  ReturnResult? _result;
  bool _loadingStocks = true;
  bool _calculating = false;
  String? _error;

  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    ApiService.fetchStocks().then((s) {
      if (mounted) {
        setState(() {
          _stocks = s;
          _selected = s.isNotEmpty ? s.first : null;
          _loadingStocks = false;
        });
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.green),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate.add(const Duration(days: 30));
        } else {
          _endDate = picked;
        }
        _result = null;
      });
    }
  }

  Future<void> _calculate() async {
    if (_selected == null) return;
    setState(() { _calculating = true; _result = null; _error = null; });
    try {
      final r = await ApiService.fetchReturn(
        _selected!.symbol,
        DateFormat('yyyy-MM-dd').format(_startDate),
        DateFormat('yyyy-MM-dd').format(_endDate),
      );
      if (mounted) setState(() { _result = r; _calculating = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _calculating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expected Return')),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_stocks.isNotEmpty)
                  DropdownButtonFormField<Stock>(
                    initialValue: _selected,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    isExpanded: true,
                    items: _stocks
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (s) => setState(() { _selected = s; _result = null; }),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _DateButton(label: 'From', date: _startDate, fmt: _fmt, onTap: () => _pickDate(isStart: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _DateButton(label: 'To', date: _endDate, fmt: _fmt, onTap: () => _pickDate(isStart: false))),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _calculating ? null : _calculate,
                    child: _calculating
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Calculate'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.red.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('Error: $_error', style: const TextStyle(color: AppTheme.red)),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultsCard(result: _result!, stock: _selected!),
                ],
                const SizedBox(height: 24),
                const Text(
                  '⚠ Historical returns do not guarantee future performance.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.date, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(fmt.format(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final ReturnResult result;
  final Stock stock;

  const _ResultsCard({required this.result, required this.stock});

  @override
  Widget build(BuildContext context) {
    final isPositive = result.pctReturn >= 0;
    final returnColor = isPositive ? AppTheme.green : AppTheme.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Over ${result.days} trading days', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Divider(height: 20),
            _MetricRow(label: 'Start Price', value: '₹${result.startPrice.toStringAsFixed(2)}'),
            _MetricRow(label: 'End Price', value: '₹${result.endPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _MetricRow(
              label: 'Total Return',
              value: '${isPositive ? '+' : ''}${result.pctReturn.toStringAsFixed(2)}%',
              valueColor: returnColor,
              bold: true,
            ),
            _MetricRow(
              label: 'CAGR',
              value: '${result.cagr >= 0 ? '+' : ''}${result.cagr.toStringAsFixed(2)}% / year',
              valueColor: result.cagr >= 0 ? AppTheme.green : AppTheme.red,
            ),
            _MetricRow(
              label: 'Annualised Volatility',
              value: '${result.annualizedVolatility.toStringAsFixed(2)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _MetricRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

