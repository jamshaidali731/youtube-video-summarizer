import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiTranslationService {
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyC0FCM6KShHtJG9IN2J59PEtOHIFyCllpw');
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<String> translateText({
    required String text,
    required String targetLanguage,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'AIzaSyC0FCM6KShHtJG9IN2J59PEtOHIFyCllpw') {
      throw Exception(
        'Gemini API key missing. Add your key or run with --dart-define=GEMINI_API_KEY=your_key',
      );
    }

    final Uri uri = Uri.parse(_endpoint);

    final Map<String, dynamic> payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': '''
Translate the following study summary into $targetLanguage.

Rules:
- Return only the translated text.
- Do not add headings, notes, explanations, or quotation marks.
- Keep the meaning accurate and natural.
- Preserve paragraph structure where possible.

Text:
$text
''',
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.2,
        'responseMimeType': 'text/plain',
      },
    };

    final http.Response response = await http
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Gemini request failed: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> candidates = data['candidates'] ?? <dynamic>[];

    if (candidates.isEmpty) {
      throw Exception('Gemini returned no translation.');
    }

    final Map<String, dynamic> firstCandidate =
        candidates.first as Map<String, dynamic>;
    final Map<String, dynamic> content =
        firstCandidate['content'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> parts = content['parts'] ?? <dynamic>[];

    if (parts.isEmpty) {
      throw Exception('Gemini returned empty translation text.');
    }

    final String translated =
        (parts.first as Map<String, dynamic>)['text']?.toString().trim() ?? '';

    if (translated.isEmpty) {
      throw Exception('Gemini returned blank translation.');
    }

    return _cleanup(translated);
  }

  static String _cleanup(String text) {
    String cleaned = text.trim();

    if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }

    return cleaned;
  }
}
