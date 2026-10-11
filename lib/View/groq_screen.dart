import 'package:ai_crop_disease_detection/Services/groq_service.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// "Ask the AI": a conversation with the AI agriculture advisor.
///
/// Opened from a diagnosis with [diseaseName], it first shows structured
/// advice for that disease and the farmer can then ask follow-up questions.
/// Opened from the home screen without [diseaseName], the farmer can ask
/// about any farming topic.
class GroqScreen extends StatefulWidget {
  final String? diseaseName;

  const GroqScreen({super.key, this.diseaseName});

  @override
  State<GroqScreen> createState() => _GroqScreenState();
}

class _GroqScreenState extends State<GroqScreen> {
  final GroqService groqService = GroqService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// The whole conversation, oldest first. Kept only while the screen is open.
  final List<ChatMessage> messages = [];
  bool isWaiting = false;
  String? errorText;

  static const List<String> _diseaseSuggestions = [
    "How fast does it spread?",
    "Can I still eat or sell the fruit?",
    "How can I treat it without chemicals?",
    "Will it come back next season?",
  ];

  static const List<String> _generalSuggestions = [
    "When should I prune my mango trees?",
    "How do I improve my soil cheaply?",
    "How much water do young trees need?",
    "How do I store fruit after harvest?",
  ];

  bool get _hasDisease => widget.diseaseName != null;

  @override
  void initState() {
    super.initState();
    if (_hasDisease) _loadFirstAdvice();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Structured advice for the diagnosed disease, shown as the AI's first
  /// message. A hidden farmer message is added first so the conversation
  /// sent with later questions reads naturally.
  Future<void> _loadFirstAdvice() async {
    setState(() {
      isWaiting = true;
      errorText = null;
    });
    final result = await groqService.getDiseaseRecommendation(
      widget.diseaseName!,
    );
    if (!mounted) return;
    setState(() {
      isWaiting = false;
      if (result.success) {
        messages.add(
          ChatMessage(
            fromFarmer: true,
            text: "Please give me advice about ${widget.diseaseName}.",
            visible: false,
          ),
        );
        messages.add(ChatMessage(fromFarmer: false, text: result.text));
      } else {
        errorText = result.text;
      }
    });
  }

  Future<void> _ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || isWaiting) return;

    _questionController.clear();
    setState(() {
      messages.add(ChatMessage(fromFarmer: true, text: text));
      isWaiting = true;
      errorText = null;
    });
    _scrollToEnd();
    await _sendConversation();
  }

  Future<void> _sendConversation() async {
    final result = await groqService.sendChat(
      messages,
      diseaseName: widget.diseaseName,
    );
    if (!mounted) return;
    setState(() {
      isWaiting = false;
      if (result.success) {
        messages.add(ChatMessage(fromFarmer: false, text: result.text));
      } else {
        errorText = result.text;
      }
    });
    _scrollToEnd();
  }

  /// Retries whatever failed: the first advice, or the last question.
  void _retry() {
    setState(() {
      isWaiting = true;
      errorText = null;
    });
    if (messages.isEmpty && _hasDisease) {
      _loadFirstAdvice();
    } else {
      _sendConversation();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages.where((m) => m.visible).toList();
    final farmerHasAsked = messages.any((m) => m.fromFarmer && m.visible);
    final showSuggestions = !farmerHasAsked && !isWaiting && errorText == null;

    return Scaffold(
      appBar: AppBar(title: const Text("Ask the AI")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(diseaseName: widget.diseaseName),
                  const SizedBox(height: 16),

                  // Welcome message when there is no diagnosis to start from.
                  if (!_hasDisease)
                    const _AiBubble(
                      text:
                          "Dumela! I'm your farming assistant. Ask me anything about your crops, pests, diseases, soil, planting or harvest.",
                    ),

                  for (final message in visibleMessages)
                    message.fromFarmer
                        ? _FarmerBubble(text: message.text)
                        : _AiBubble(text: message.text),

                  if (isWaiting) const _ThinkingBubble(),
                  if (errorText != null)
                    _ErrorBubble(text: errorText!, onRetry: _retry),

                  if (showSuggestions) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Tap a question or type your own:",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          (_hasDisease
                                  ? _diseaseSuggestions
                                  : _generalSuggestions)
                              .map(
                                (q) => ActionChip(
                                  avatar: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  label: Text(q),
                                  labelStyle: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 14.5,
                                  ),
                                  backgroundColor: AppColors.primaryLight,
                                  side: BorderSide.none,
                                  onPressed: () => _ask(q),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ],
              ),
            ),
            _QuestionBar(
              controller: _questionController,
              enabled: !isWaiting,
              onSend: () => _ask(_questionController.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the conversation is about, plus an honest note about AI limits.
class _Header extends StatelessWidget {
  const _Header({required this.diseaseName});

  final String? diseaseName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                child: Icon(Icons.auto_awesome, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diseaseName == null ? "Farming assistant" : "Advice for",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      diseaseName ?? "Ask me anything",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "AI answers can be wrong. For serious or spreading problems, speak to your local agricultural extension officer.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 32),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        // The AI replies in markdown (headings and bullet points).
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            h2: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              height: 1.8,
            ),
            h3: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            p: const TextStyle(fontSize: 16, height: 1.45),
            listBullet: const TextStyle(fontSize: 16, color: AppColors.primary),
            strong: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _FarmerBubble extends StatelessWidget {
  const _FarmerBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 10),
            Text("Thinking...", style: TextStyle(fontSize: 15.5)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Try again"),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text box and send button at the bottom of the screen.
class _QuestionBar extends StatelessWidget {
  const _QuestionBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: GroqService.maxQuestionLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: "Type your question...",
                counterText: "",
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: "Send",
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(52, 52),
            ),
            icon: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
