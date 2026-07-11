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
import 'screens/settings_screen.dart';
import 'screens/all_stocks_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/market_breadth_screen.dart';
import 'screens/market_trends_screen.dart';
import 'screens/vix_screen.dart';
import 'screens/sip_calculator_screen.dart';

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
    WatchlistScreen(),
  ];

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined),            activeIcon: Icon(Icons.home),            label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),       activeIcon: Icon(Icons.bar_chart),       label: 'Signals'),
    BottomNavigationBarItem(icon: Icon(Icons.radar_outlined),           activeIcon: Icon(Icons.radar),           label: 'Intraday'),
    BottomNavigationBarItem(icon: Icon(Icons.star_border_rounded),      activeIcon: Icon(Icons.star_rounded),    label: 'Watchlist'),
  ];

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(onNavigate: _push),
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
        onPressed: () => _push(const AiChatScreen()),
        backgroundColor: AppTheme.blue,
        mini: true,
        tooltip: 'AI Chat',
        child: const Icon(Icons.psychology_rounded, color: Colors.white),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _AppDrawer({required this.onNavigate});

  void _go(BuildContext ctx, Widget screen) {
    Navigator.pop(ctx);
    onNavigate(screen);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.green, Color(0xFF00897B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.show_chart, color: Colors.white, size: 36),
              SizedBox(height: 8),
              Text('StockSense', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('NSE/BSE Intelligence', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _Section('Trading'),
            _DrawerItem(icon: Icons.bolt_outlined,         label: 'F&O Options',      onTap: () => _go(context, const FnoScreen())),
            _DrawerItem(icon: Icons.book_outlined,         label: 'Trade Planner',    onTap: () => _go(context, const PlannerScreen())),
            _DrawerItem(icon: Icons.compare_arrows_rounded,label: 'Compare Stocks',   onTap: () => _go(context, const CompareScreen())),
            _Section('Market'),
            _DrawerItem(icon: Icons.list_alt_outlined,     label: 'All Stocks',       onTap: () => _go(context, const AllStocksScreen())),
            _DrawerItem(icon: Icons.bar_chart_rounded,     label: 'Market Breadth',   onTap: () => _go(context, const MarketBreadthScreen())),
            _DrawerItem(icon: Icons.trending_up_rounded,   label: 'Market Trends',    onTap: () => _go(context, const MarketTrendsScreen())),
            _DrawerItem(icon: Icons.whatshot_rounded,      label: 'India VIX',        onTap: () => _go(context, const VixScreen())),
            _Section('Tools'),
            _DrawerItem(icon: Icons.psychology_rounded,    label: 'AI Chat',          onTap: () => _go(context, const AiChatScreen())),
            _DrawerItem(icon: Icons.calculate_outlined,    label: 'SIP Calculator',   onTap: () => _go(context, const SipCalculatorScreen())),
            _DrawerItem(icon: Icons.settings_outlined,     label: 'Settings',         onTap: () => _go(context, const SettingsScreen())),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Data: Yahoo Finance / yfinance\nFor educational use only',
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1.2)),
  );
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: AppTheme.textPrimary),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    onTap: onTap,
    dense: true,
    horizontalTitleGap: 8,
  );
}
