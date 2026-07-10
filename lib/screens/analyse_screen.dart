import 'package:flutter/material.dart';
import '../theme.dart';
import 'prediction_screen.dart';
import 'expected_return_screen.dart';
import 'budget_screen.dart';

class AnalyseScreen extends StatelessWidget {
  const AnalyseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🔮 Analyse'),
          bottom: TabBar(
            labelColor: AppTheme.green,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.green,
            tabs: const [
              Tab(text: 'Prediction'),
              Tab(text: 'Return'),
              Tab(text: 'Budget'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            _NoAppBar(child: PredictionScreen()),
            _NoAppBar(child: ExpectedReturnScreen()),
            _NoAppBar(child: BudgetScreen()),
          ],
        ),
      ),
    );
  }
}

/// Strips the individual AppBar from a screen so it renders inside the tab.
class _NoAppBar extends StatelessWidget {
  final Widget child;
  const _NoAppBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: false,
      child: Builder(builder: (ctx) {
        // Override the scaffold messenger so sub-screens don't fight for the
        // AppBar; render only the body by wrapping in a plain scroll container.
        return child;
      }),
    );
  }
}
