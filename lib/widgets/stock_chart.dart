import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme.dart';

class StockChart extends StatelessWidget {
  final List<HistoryPoint> data;
  final bool showSMA;
  final double height;

  const StockChart({
    super.key,
    required this.data,
    this.showSMA = true,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final closeSpots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();

    final sma20Spots = <FlSpot>[];
    final sma50Spots = <FlSpot>[];
    if (showSMA) {
      for (int i = 0; i < data.length; i++) {
        if (data[i].sma20 != null) sma20Spots.add(FlSpot(i.toDouble(), data[i].sma20!));
        if (data[i].sma50 != null) sma50Spots.add(FlSpot(i.toDouble(), data[i].sma50!));
      }
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 62,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '₹${v.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: closeSpots,
              color: AppTheme.green,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.green.withOpacity(0.08),
              ),
            ),
            if (sma20Spots.isNotEmpty)
              LineChartBarData(
                spots: sma20Spots,
                color: AppTheme.blue,
                barWidth: 1.2,
                dotData: const FlDotData(show: false),
                dashArray: [5, 4],
              ),
            if (sma50Spots.isNotEmpty)
              LineChartBarData(
                spots: sma50Spots,
                color: AppTheme.red,
                barWidth: 1.2,
                dotData: const FlDotData(show: false),
                dashArray: [5, 4],
              ),
          ],
        ),
      ),
    );
  }
}

class RSIChart extends StatelessWidget {
  final List<HistoryPoint> data;

  const RSIChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i].rsi14 != null) spots.add(FlSpot(i.toDouble(), data[i].rsi14!));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 130,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => (v == 30 || v == 70)
                    ? Text('${v.toInt()}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: 70, color: AppTheme.red, strokeWidth: 1, dashArray: [4, 4]),
            HorizontalLine(y: 30, color: AppTheme.green, strokeWidth: 1, dashArray: [4, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppTheme.blue,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
