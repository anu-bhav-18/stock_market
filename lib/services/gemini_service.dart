import 'package:google_generative_ai/google_generative_ai.dart';
import 'settings_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser}) : time = DateTime.now();
}

class GeminiService {
  static GenerativeModel? _model;
  static ChatSession? _chat;

  static Future<bool> init() async {
    final key = await SettingsService.getGeminiKey();
    if (key.isEmpty) return false;
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
      systemInstruction: Content.system(
        'You are StockSense AI, an expert Indian stock market analyst. '
        'You help retail investors understand NSE/BSE stocks, technical signals, '
        'F&O concepts, and market trends. Always give clear, practical advice. '
        'Mention that this is for educational purposes, not financial advice. '
        'Keep responses concise (under 200 words unless asked for detail). '
        'Use ₹ for prices and % for returns. Focus on Indian markets (NSE/BSE).',
      ),
    );
    _chat = _model!.startChat();
    return true;
  }

  static Future<String> send(String message) async {
    if (_model == null) {
      final ok = await init();
      if (!ok) return 'Please set your Gemini API key in Settings first.';
    }
    try {
      final response = await _chat!.sendMessage(Content.text(message));
      return response.text ?? 'No response received.';
    } on GenerativeAIException catch (e) {
      if (e.message.contains('API_KEY')) return 'Invalid API key. Go to Settings and update it.';
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Error connecting to Gemini: $e';
    }
  }

  static Future<String> analyzeStock({
    required String symbol,
    required String name,
    required double price,
    required double changePct,
    required String signal,
    required double score,
    required double? mlProb,
    required List<String> reasons,
  }) async {
    final prompt = '''
Analyze this NSE stock for me:

**$name ($symbol)**
- Current Price: ₹${price.toStringAsFixed(2)}
- Today's Change: ${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%
- Technical Signal: $signal (score: ${score.toStringAsFixed(0)}/100)
${mlProb != null ? '- ML Probability Up: ${(mlProb * 100).toStringAsFixed(1)}%' : ''}
- Key Signals: ${reasons.take(3).join(', ')}

Give me: 1) Quick analysis 2) Should I buy/sell/hold? 3) Key risk to watch.
''';
    return send(prompt);
  }

  static void reset() {
    if (_model != null) _chat = _model!.startChat();
  }
}
