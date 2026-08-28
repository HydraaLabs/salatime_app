import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zabi/helper/debug_http_client.dart';
import 'package:zabi/util/app_constants.dart';
import '../model/response/islamic_name_model.dart';

class IslamicNameRepo {
  Future<List<IslamicName>> generateNames({
    required String gender,
    required String origin,
    String? meaningTheme,
    String? startsWithLetter,
    int count = 15,
    required dynamic islamicNameApiKey,
  }) async {
    final response = await appHttpClient.post(
      Uri.parse(AppConstants.AI_GENERATE_NAMES_URI),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'gender': gender,
        'origin': origin,
        'theme': meaningTheme ?? '',
        'starts_with': startsWithLetter ?? '',
        'count': count,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint("Name generator API error: ${response.statusCode}");
      throw Exception('API error ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'AI service unavailable');
    }

    final List<dynamic> jsonList = data['names'] ?? [];
    return jsonList
        .map((e) => IslamicName.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
