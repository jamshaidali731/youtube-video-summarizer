import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiStudyService {
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyC0FCM6KShHtJG9IN2J59PEtOHIFyCllpw');
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<Map<String, dynamic>> generateStudyMaterial(String summary) async {
    if (_apiKey.isEmpty || _apiKey == 'AIzaSyC0FCM6KShHtJG9IN2J59PEtOHIFyCllpw') {
      throw Exception(
        'Gemini API key missing. Add your key in gemini_study_service.dart or pass --dart-define=GEMINI_API_KEY=your_key',
      );
    }

    final Uri uri = Uri.parse(_endpoint);

    final Map<String, dynamic> payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': '''
You are an academic study assistant.
From the summary below, generate structured study material.

Return valid JSON with exactly these keys:
- notes: array of short bullet-style notes
- mcqs: array of objects with question, options, answer
- quiz: array of short quiz prompts
- qa: array of objects with question, answer

Rules:
- Keep language simple and student-friendly.
- Create 4 to 6 notes.
- Create 4 MCQs, each with exactly 4 options.
- Create 4 quiz prompts.
- Create 4 Q&A items.
- Base everything only on the summary.

Summary:
$summary
''',
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.4,
        'responseMimeType': 'application/json',
        'responseSchema': <String, dynamic>{
          'type': 'OBJECT',
          'properties': <String, dynamic>{
            'notes': <String, dynamic>{
              'type': 'ARRAY',
              'items': <String, dynamic>{'type': 'STRING'},
            },
            'mcqs': <String, dynamic>{
              'type': 'ARRAY',
              'items': <String, dynamic>{
                'type': 'OBJECT',
                'properties': <String, dynamic>{
                  'question': <String, dynamic>{'type': 'STRING'},
                  'options': <String, dynamic>{
                    'type': 'ARRAY',
                    'items': <String, dynamic>{'type': 'STRING'},
                  },
                  'answer': <String, dynamic>{'type': 'STRING'},
                },
                'required': <String>['question', 'options', 'answer'],
              },
            },
            'quiz': <String, dynamic>{
              'type': 'ARRAY',
              'items': <String, dynamic>{'type': 'STRING'},
            },
            'qa': <String, dynamic>{
              'type': 'ARRAY',
              'items': <String, dynamic>{
                'type': 'OBJECT',
                'properties': <String, dynamic>{
                  'question': <String, dynamic>{'type': 'STRING'},
                  'answer': <String, dynamic>{'type': 'STRING'},
                },
                'required': <String>['question', 'answer'],
              },
            },
          },
          'required': <String>['notes', 'mcqs', 'quiz', 'qa'],
        },
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
      throw Exception('Gemini request failed: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> candidates = data['candidates'] ?? <dynamic>[];

    if (candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final Map<String, dynamic> firstCandidate =
        candidates.first as Map<String, dynamic>;
    final Map<String, dynamic> content =
        firstCandidate['content'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> parts = content['parts'] ?? <dynamic>[];

    if (parts.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    final String responseText = (parts.first as Map<String, dynamic>)['text']?.toString() ?? '';
    if (responseText.isEmpty) {
      throw Exception('Gemini response text was empty.');
    }

    final dynamic decoded = jsonDecode(responseText);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected Gemini JSON format.');
    }

    return _normalizeStudyMaterial(decoded);
  }

  static Map<String, dynamic> _normalizeStudyMaterial(Map<String, dynamic> data) {
    final List<String> notes = (data['notes'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();

    final List<String> quiz = (data['quiz'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();

    final List<Map<String, dynamic>> mcqs =
        (data['mcqs'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> item) {
      final List<String> options = (item['options'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic option) => option.toString().trim())
          .where((String option) => option.isNotEmpty)
          .take(4)
          .toList();

      return <String, dynamic>{
        'question': item['question']?.toString().trim() ?? '',
        'options': options,
        'answer': item['answer']?.toString().trim() ?? '',
      };
    }).where((Map<String, dynamic> item) {
      return (item['question'] as String).isNotEmpty &&
          (item['options'] as List<String>).length == 4;
    }).toList();

    final List<Map<String, dynamic>> qa = (data['qa'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) {
      return <String, dynamic>{
        'question': item['question']?.toString().trim() ?? '',
        'answer': item['answer']?.toString().trim() ?? '',
      };
    }).where((Map<String, dynamic> item) {
      return (item['question'] as String).isNotEmpty &&
          (item['answer'] as String).isNotEmpty;
    }).toList();

    return <String, dynamic>{
      'notes': notes,
      'mcqs': mcqs,
      'quiz': quiz,
      'qa': qa,
    };
  }
}
