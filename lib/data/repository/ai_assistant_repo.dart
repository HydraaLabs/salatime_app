import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zabi/util/app_constants.dart';

class AiAssistantRepo {
  Future<String> askAI({
    required String question,
    required dynamic apiKey,
  }) async {
    final response = await http.post(
      Uri.parse(AppConstants.GROK_END_POINT),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "llama-3.1-8b-instant",
        "temperature": 0.7,
        "max_tokens": 2048,
        "messages": [
          {
            "role": "system",
            "content":
            "You are a knowledgeable Islamic scholar. Give authentic Islamic answers. Keep answers concise and clear."
          },
          {
            "role": "user",
            "content": question
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("API Error: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);

    return data['choices'][0]['message']['content'];
  }
}