import 'package:flutter_test/flutter_test.dart';

import 'package:ai_crop_disease_detection/Services/groq_service.dart';

void main() {
  test('chat request starts with instructions, then the conversation', () {
    final request = GroqService.buildChatRequest(const [
      ChatMessage(fromFarmer: true, text: "How fast does it spread?"),
      ChatMessage(fromFarmer: false, text: "Within a few days."),
      ChatMessage(fromFarmer: true, text: "Can I eat the fruit?"),
    ], diseaseName: "Anthracnose");

    expect(request.first["role"], "system");
    expect(request.first["content"], contains("Anthracnose"));
    expect(request.sublist(1).map((m) => m["role"]), [
      "user",
      "assistant",
      "user",
    ]);
    expect(request.last["content"], "Can I eat the fruit?");
  });

  test('only the most recent messages are sent', () {
    final history = List.generate(
      30,
      (i) => ChatMessage(fromFarmer: i.isEven, text: "message $i"),
    );
    final request = GroqService.buildChatRequest(history);

    // 1 instruction message + the last 12 messages of the conversation.
    expect(request.length, 1 + GroqService.maxHistoryMessages);
    expect(request[1]["content"], "message 18");
    expect(request.last["content"], "message 29");
  });

  test('hidden context messages are still sent to the AI', () {
    final request = GroqService.buildChatRequest(const [
      ChatMessage(
        fromFarmer: true,
        text: "Please give me advice about Die Back.",
        visible: false,
      ),
      ChatMessage(fromFarmer: false, text: "## What it is ..."),
    ], diseaseName: "Die Back");

    expect(request[1]["content"], "Please give me advice about Die Back.");
  });

  test('general chat has no disease in the instructions', () {
    final prompt = GroqService.systemPrompt();
    expect(prompt, contains("any farming topic"));
    expect(prompt, contains("only help with farming"));
  });
}
