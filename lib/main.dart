import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/expected_return_screen.dart';
import 'screens/top_movers_screen.dart';
import 'screens/budget_screen.dart';

void main() {
  runApp(const StockSenseApp());
}

class StockSenseApp extends StatelessWidget {
  const StockSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockSense',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    PredictionScreen(),
    ExpectedReturnScreen(),
    TopMoversScreen(),
    BudgetScreen(),
  ];

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), activeIcon: Icon(Icons.auto_graph), label: 'Predict'),
    BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), activeIcon: Icon(Icons.trending_up), label: 'Return'),
    BottomNavigationBarItem(icon: Icon(Icons.rocket_launch_outlined), activeIcon: Icon(Icons.rocket_launch), label: 'Movers'),
    BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate), label: 'Budget'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.green,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: _items,
      ),
    );
  }
}
