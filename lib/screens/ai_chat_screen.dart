import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? initialMessage;
  const AiChatScreen({super.key, this.initialPrompt, this.initialMessage});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _thinking = false;
  bool _hasKey   = false;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final key = await SettingsService.getGeminiKey();
    setState(() => _hasKey = key.isNotEmpty);
    if (_hasKey) {
      _addBot('Hi! I\'m StockSense AI powered by Gemini. Ask me anything about NSE/BSE stocks, technical analysis, F&O, or market trends.');
      if (widget.initialMessage != null) {
        _addBot(widget.initialMessage!);
      } else if (widget.initialPrompt != null) {
        await _send(widget.initialPrompt!);
      }
    }
  }

  void _addBot(String text) {
    setState(() => _messages.add(ChatMessage(text: text, isUser: false)));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? override]) async {
    final text = override ?? _ctrl.text.trim();
    if (text.isEmpty || _thinking) return;
    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _thinking = true;
    });
    _scrollDown();
    final reply = await GeminiService.send(text);
    if (mounted) {
      setState(() { _thinking = false; });
      _addBot(reply);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.psychology_rounded, color: AppTheme.blue, size: 20),
          SizedBox(width: 8),
          Text('AI Chat'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New chat',
            onPressed: () {
              GeminiService.reset();
              setState(() => _messages.clear());
              _addBot('Chat reset! Ask me anything about the Indian stock market.');
            },
          ),
        ],
      ),
      body: !_hasKey ? _NoKeyView() : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _ThinkingBubble();
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          _QuickPrompts(onTap: _send),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Ask about any NSE stock...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppTheme.bg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _thinking ? null : () => _send(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _thinking ? AppTheme.textSecondary : AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                  child: _thinking
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.green : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Text(
          msg.text,
          style: TextStyle(fontSize: 13, color: isUser ? Colors.white : AppTheme.textPrimary, height: 1.4),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(delay: 0), _Dot(delay: 150), _Dot(delay: 300),
      ]),
    ),
  );
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: FadeTransition(
      opacity: _anim,
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.textSecondary, shape: BoxShape.circle)),
    ),
  );
}

class _QuickPrompts extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickPrompts({required this.onTap});

  static const _prompts = [
    'What is RSI?',
    'Explain PCR in F&O',
    'What is max pain?',
    'How to read MACD?',
    'Best Nifty 50 stocks?',
    'What is OI buildup?',
  ];

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.bg,
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _prompts.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => onTap(_prompts[i]),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(_prompts[i], style: const TextStyle(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}

class _NoKeyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.key_rounded, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        const Text('Gemini API Key Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Get a free key at ai.google.dev and add it in Settings.',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('Open Settings'),
        ),
      ]),
    ),
  );
}
