import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiCtrl = TextEditingController();
  final _apiCtrl    = TextEditingController();
  bool _showKey = false;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _geminiCtrl.text = await SettingsService.getGeminiKey();
    _apiCtrl.text    = await SettingsService.getApiBase();
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SettingsService.setGeminiKey(_geminiCtrl.text.trim());
    await SettingsService.setApiBase(_apiCtrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), backgroundColor: AppTheme.green),
      );
    }
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _apiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('AI Chat — Gemini API'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get a free API key at ai.google.dev → Get API Key',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _geminiCtrl,
                    obscureText: !_showKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'AIza...',
                      suffixIcon: IconButton(
                        icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showKey = !_showKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Free tier: 15 requests/min, 1500/day (Gemini 1.5 Flash)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Backend API'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _apiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://angelmod.vercel.app',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leave default unless you have a custom deployment',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Settings'),
            ),
          ),
          const SizedBox(height: 32),
          _SectionHeader('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('StockSense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('NSE/BSE stock analysis app with technical signals, ML predictions, F&O analytics, and AI chat.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  SizedBox(height: 12),
                  Text('Data Sources', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• Prices & Options: Yahoo Finance (yfinance)\n'
                       '• Technical Analysis: Custom Python engine\n'
                       '• ML Predictions: Logistic Regression on 6-month history\n'
                       '• AI Chat: Google Gemini 1.5 Flash',
                       style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  SizedBox(height: 12),
                  Text('⚠ For educational use only. Not financial advice.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
  );
}
