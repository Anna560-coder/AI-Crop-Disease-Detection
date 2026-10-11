import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of an AI request: the text to show and whether it worked,
/// so the screen can offer "Try again" on errors.
class AdviceResult {
  const AdviceResult(this.text, {this.success = true});
  const AdviceResult.error(this.text) : success = false;

  final String text;
  final bool success;
}

/// One message in a conversation with the AI.
class ChatMessage {
  const ChatMessage({
    required this.fromFarmer,
    required this.text,
    this.visible = true,
  });

  /// true = the farmer wrote it; false = the AI wrote it.
  final bool fromFarmer;
  final String text;

  /// false for context the app adds itself (sent to the AI, not shown).
  final bool visible;

  Map<String, String> toApi() => {
    "role": fromFarmer ? "user" : "assistant",
    "content": text,
  };
}

class GroqService {
  // Injected at build time so the key is never committed to source control:
  //   flutter run --dart-define-from-file=env.json
  // See env.example.json for the expected format.
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');

  static const String _url = "https://api.groq.com/openai/v1/chat/completions";

  /// How many earlier messages are sent with each question. Keeps requests
  /// small (and cheap) on slow rural networks while keeping the context.
  static const int maxHistoryMessages = 12;

  /// Longest question a farmer can type.
  static const int maxQuestionLength = 500;

  /// Instructions sent with every chat request. [diseaseName] is the
  /// diagnosis the conversation is about, if any.
  static String systemPrompt({String? diseaseName}) {
    final topic = diseaseName == null
        ? "The farmer may ask about any farming topic."
        : "The farmer's crop was diagnosed with: $diseaseName. Questions are "
              "usually about this diagnosis.";
    return """
You are a friendly agriculture extension officer helping a small-scale
farmer in Nketoana Local Municipality, Free State, South Africa.
$topic

Rules:
- Use simple, everyday English that a farmer with little formal schooling understands.
- Keep answers short: at most 150 words, using short bullet points where helpful.
- Prefer low-cost methods a small-scale farmer can do by hand.
- If you mention a chemical, say to use a product registered in South Africa and to follow the label.
- Do not use tables.
- If you are not sure, say so and suggest asking the local agricultural extension officer.
- If the question is not about farming, politely say you can only help with farming questions.
""";
  }

  /// Builds the messages sent to the API: the instructions, then the most
  /// recent [maxHistoryMessages] messages of the conversation.
  static List<Map<String, String>> buildChatRequest(
    List<ChatMessage> history, {
    String? diseaseName,
  }) {
    final recent = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    return [
      {"role": "system", "content": systemPrompt(diseaseName: diseaseName)},
      ...recent.map((m) => m.toApi()),
    ];
  }

  /// The first, structured advice for a diagnosed disease.
  Future<AdviceResult> getDiseaseRecommendation(String diseaseName) {
    final prompt =
        """
You are an agriculture extension officer helping a small-scale farmer in
Nketoana Local Municipality, Free State, South Africa.

The farmer's crop has: $diseaseName

Write clear, practical advice using these four headings (markdown "##"):
## What it is
## Common causes
## How to treat it
## How to prevent it

Rules:
- Use simple, everyday English that a farmer with little formal schooling understands.
- Use short bullet points (no more than 4 per heading).
- Prefer low-cost methods a small-scale farmer can do by hand.
- If you mention a chemical, say to use a product registered in South Africa and to follow the label.
- Do not use tables.
- Keep the whole answer under 250 words.
""";
    return _send([
      {"role": "user", "content": prompt},
    ]);
  }

  /// A follow-up question in an ongoing conversation. [history] must end
  /// with the farmer's new question.
  Future<AdviceResult> sendChat(
    List<ChatMessage> history, {
    String? diseaseName,
  }) {
    return _send(buildChatRequest(history, diseaseName: diseaseName));
  }

  Future<AdviceResult> _send(List<Map<String, String>> messages) async {
    if (apiKey.isEmpty) {
      return const AdviceResult.error(
        "AI advice is not set up yet. Please contact the app administrator.",
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              "Authorization": "Bearer $apiKey",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model": "openai/gpt-oss-20b",
              "messages": messages,
              // Faster answers; the hidden reasoning is not downloaded.
              "reasoning_effort": "low",
              "include_reasoning": false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data["choices"][0]["message"]["content"] as String?;
        if (content == null || content.trim().isEmpty) {
          return const AdviceResult.error(
            "No answer was returned. Please try again.",
          );
        }
        return AdviceResult(content.trim());
      } else {
        return AdviceResult.error(
          "The AI service is busy right now (error ${response.statusCode}). Please try again later.",
        );
      }
    } on TimeoutException {
      return const AdviceResult.error(
        "The AI service took too long to respond. Please try again.",
      );
    } catch (e) {
      return const AdviceResult.error(
        "No internet connection. Please check your network and try again.",
      );
    }
  }
}
