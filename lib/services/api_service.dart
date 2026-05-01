import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiResponse {
  final bool success;
  final String message;
  final String? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
}

class ApiService {
  static const String baseUrl =
      'https://jamshaidali3943-youtube-video-summarizer.hf.space';

  // Adjust these presets if you want shorter or longer responses from the API.
  static const Map<String, Map<String, String>> _lengthPresets =
      <String, Map<String, String>>{
    'short': <String, String>{
      'max_length': '120',
      'min_length': '30',
    },
    'detailed': <String, String>{
      'max_length': '260',
      'min_length': '80',
    },
  };

  static Future<ApiResponse> summarizeVideo({
    required String url,
    required String type,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/summarize-video');
      final Map<String, String> selectedPreset =
          _lengthPresets[type] ?? _lengthPresets['short']!;

      final request = http.MultipartRequest('POST', uri)
        ..fields['video_url'] = url
        ..fields['max_length'] = selectedPreset['max_length']!
        ..fields['min_length'] = selectedPreset['min_length']!;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 500));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final dynamic data = jsonDecode(responseBody);

        if (data is Map) {
          final summary = data['summary'] ?? data['result'] ?? data['text'];

          if (summary != null && summary.toString().isNotEmpty) {
            return ApiResponse(
              success: true,
              message: 'Summary generated successfully',
              data: summary.toString(),
            );
          }
        }

        return ApiResponse(
          success: false,
          message: 'Summary not found in API response',
        );
      }

      return ApiResponse(
        success: false,
        message: 'Server Error: ${streamedResponse.statusCode} $responseBody',
      );
    } on http.ClientException {
      return ApiResponse(
        success: false,
        message: 'No internet connection',
      );
    } on FormatException {
      return ApiResponse(
        success: false,
        message: 'Invalid response format',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }
}
