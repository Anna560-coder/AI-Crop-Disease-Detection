import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey =
      "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";

  Future<String> getDiseaseRecommendation(String diseaseName) async {
    const String url = "https://api.groq.com/openai/v1/chat/completions";

    final prompt =
        """
You are an agriculture expert.

Provide clear advice for a farmer.

Disease: $diseaseName

Include:
1. What the disease is
2. Common causes
3. Treatment steps
4. Prevention tips

Use simple language.
""";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "openai/gpt-oss-20b",
          "messages": [
            {"role": "user", "content": prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["choices"][0]["message"]["content"] ??
            "No recommendation available.";
      } else {
        return "AI service error: ${response.statusCode}\n${response.body}";
      }
    } catch (e) {
      return "AI service unavailable. Please check your internet connection.";
    }
  }
}
