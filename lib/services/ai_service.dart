import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String _configuredBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');

  static String _resolveBaseUrl() {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return Uri.base.origin;
    }

    throw Exception(
      'BACKEND_BASE_URL is not configured. Pass it with --dart-define=BACKEND_BASE_URL=https://your-api-url',
    );
  }

  static Future<Map<String, dynamic>> processMeetingAudio(
    Uint8List fileBytes,
    String fileName,
  ) async {
    final baseUrl = _resolveBaseUrl();
    final url = Uri.parse('$baseUrl/api/process-meeting');

    final request = http.MultipartRequest('POST', url)
      ..files.add(
        http.MultipartFile.fromBytes(
          'audio',
          fileBytes,
          filename: fileName,
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Meeting processing failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backend response format.');
    }

    return decoded;
  }
}
