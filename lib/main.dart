import 'package:flutter/material.dart';
import 'services/alert_service.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/intraday_screen.dart';
import 'screens/signals_screen.dart';
import 'screens/fno_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/ai_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.init();
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
    PortfolioScreen(),
    SignalsScreen(),
    IntradayScreen(),
    FnoScreen(),
    WatchlistScreen(),
  ];

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined),            activeIcon: Icon(Icons.home),            label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),       activeIcon: Icon(Icons.bar_chart),       label: 'Signals'),
    BottomNavigationBarItem(icon: Icon(Icons.radar_outlined),           activeIcon: Icon(Icons.radar),           label: 'Intraday'),
    BottomNavigationBarItem(icon: Icon(Icons.bolt_outlined),            activeIcon: Icon(Icons.bolt),            label: 'F&O'),
    BottomNavigationBarItem(icon: Icon(Icons.star_border_rounded),      activeIcon: Icon(Icons.star_rounded),    label: 'Watchlist'),
  ];

  void _openChat() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));

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
        selectedFontSize: 9,
        unselectedFontSize: 9,
        iconSize: 22,
        items: _items,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChat,
        backgroundColor: AppTheme.blue,
        mini: true,
        tooltip: 'AI Chat',
        child: const Icon(Icons.psychology_rounded, color: Colors.white),
      ),
    );
  }
}
