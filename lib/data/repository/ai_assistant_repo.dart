import 'dart:convert';
import 'package:salatime/helper/debug_http_client.dart';
import 'package:salatime/util/app_constants.dart';

class AiAssistantRepo {
  Future<String> askAI({
    required String question,
    required dynamic apiKey,
  }) async {
    final response = await appHttpClient.post(
      Uri.parse(AppConstants.AI_CHAT_URI),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': question}),
    );

    if (response.statusCode != 200) {
      throw Exception("API Error: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'AI service unavailable');
    }

    return data['reply'] ?? '';
  }
}
