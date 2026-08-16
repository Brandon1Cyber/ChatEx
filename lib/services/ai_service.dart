import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Replace with your OpenAI API key
  static const String apiKey = "YOUR_OPENAI_API_KEY";

  static const String apiUrl =
      "https://api.openai.com/v1/chat/completions";

  Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4.1-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are ChatEx AI, a friendly, intelligent assistant inside the ChatEx messaging app. Answer clearly and helpfully."
            },
            {
              "role": "user",
              "content": message
            }
          ],
          "temperature": 0.7,
          "max_tokens": 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data["choices"][0]["message"]["content"]
            .toString()
            .trim();
      } else {
        return "OpenAI Error ${response.statusCode}\n${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}