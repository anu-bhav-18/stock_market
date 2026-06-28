import 'package:flutter/material.dart';
import '../theme.dart';

class SignalPill extends StatelessWidget {
  final String label;

  const SignalPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (label) {
      case 'Strong Buy':
        bg = AppTheme.green;
        fg = Colors.white;
      case 'Buy':
        bg = AppTheme.green.withOpacity(0.15);
        fg = AppTheme.green;
      case 'Strong Sell':
        bg = AppTheme.red;
        fg = Colors.white;
      case 'Sell':
        bg = AppTheme.red.withOpacity(0.15);
        fg = AppTheme.red;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
