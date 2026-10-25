import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../core/models/detection_model.dart';
import '../../../../core/services/ai_assistant_service.dart';
import '../../../../core/services/firestore_service.dart';

const _suggestions = [
  'What caused this defect?',
  'How do I fix it?',
  'Should I stop the print?',
  'Will it affect print quality?',
  'How can I prevent this next time?',
];

class AiAssistantScreen extends ConsumerStatefulWidget {
  final DetectionRecord record;
  const AiAssistantScreen({super.key, required this.record});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _assistantService = AiAssistantService();
  final _firestoreService = FirestoreService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadOrExplain();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrExplain() async {
    if (widget.record.id != null) {
      final history = await _firestoreService.loadChatHistory(widget.record.id!);
      if (history.isNotEmpty) {
        setState(() => _messages.addAll(history));
        _scrollToBottom();
        return;
      }
    }
    await _generateExplanation();
  }

  Future<void> _generateExplanation() async {
    setState(() => _isLoading = true);
    final explanation = await _assistantService.explainDetection(widget.record);
    setState(() {
      _messages.add(ChatMessage(
        content: explanation,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
      _showSuggestions = true;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _controller.clear();
    setState(() {
      _showSuggestions = false;
      _messages.add(ChatMessage(
        content: text.trim(),
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _assistantService.sendMessage(
      history: _messages,
      userMessage: text.trim(),
    );

    setState(() {
      _messages.add(ChatMessage(
        content: response,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();

    if (widget.record.id != null) {
      await _firestoreService.saveChatHistory(
        detectionId: widget.record.id!,
        messages: _messages,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Assistant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(record.className,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AlertLevel.color(record.alertLevel).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              record.alertLevel,
              style: TextStyle(
                color: AlertLevel.color(record.alertLevel),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _DetectionHeader(record: record),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) return const _TypingIndicator();
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),
          if (_showSuggestions && !_isLoading)
            _SuggestionChips(onTap: _sendMessage),
          _InputBar(
            controller: _controller,
            isLoading: _isLoading,
            onSend: () => _sendMessage(_controller.text),
          ),
        ],
      ),
    );
  }
}

// ── Detection image + info header ────────────────────────────────────────────

class _DetectionHeader extends StatelessWidget {
  final DetectionRecord record;
  const _DetectionHeader({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (record.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                record.imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(Icons.broken_image, color: AppColors.textHint),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.className,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                Text('Confidence: ${record.confidencePercent}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 13)),
                if (record.printerName != null)
                  Text('Printer: ${record.printerName}',
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Animated typing indicator ─────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (_, __) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(0.4 + 0.6 * _controllers[i].value),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Suggestion chips ──────────────────────────────────────────────────────────

class _SuggestionChips extends StatelessWidget {
  final void Function(String) onTap;
  const _SuggestionChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.surface,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _suggestions
            .map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onTap(s),
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle:
                      const TextStyle(color: AppColors.textPrimary),
                ))
            .toList(),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask about this defect...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : onSend,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            color: AppColors.primary,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}