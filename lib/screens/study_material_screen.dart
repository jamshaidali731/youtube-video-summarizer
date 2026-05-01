import 'package:flutter/material.dart';

import '../services/gemini_study_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({
    super.key,
    required this.summary,
    this.initialTab = 0,
  });

  final String summary;
  final int initialTab;

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<String> notes = <String>[];
  List<Map<String, dynamic>> mcqs = <Map<String, dynamic>>[];
  List<String> quizPrompts = <String>[];
  List<Map<String, dynamic>> qaItems = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    generateStudyMaterial();
  }

  Future<void> generateStudyMaterial() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final Map<String, dynamic> result =
          await GeminiStudyService.generateStudyMaterial(widget.summary);

      if (!mounted) {
        return;
      }

      setState(() {
        notes = List<String>.from(result['notes'] ?? <String>[]);
        mcqs = List<Map<String, dynamic>>.from(result['mcqs'] ?? <Map<String, dynamic>>[]);
        quizPrompts = List<String>.from(result['quiz'] ?? <String>[]);
        qaItems = List<Map<String, dynamic>>.from(result['qa'] ?? <Map<String, dynamic>>[]);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Widget buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Generating study material...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Please wait while Gemini prepares notes, MCQs, quiz, and Q&A'),
        ],
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
            const SizedBox(height: 14),
            const Text(
              'Study material could not be generated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: generateStudyMaterial,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNotesTab() {
    if (notes.isEmpty) {
      return buildEmptyState('No notes returned by Gemini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (_, int index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.notes_rounded),
            title: Text('Note ${index + 1}'),
            subtitle: Text(notes[index]),
          ),
        );
      },
    );
  }

  Widget buildMcqsTab() {
    if (mcqs.isEmpty) {
      return buildEmptyState('No MCQs returned by Gemini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mcqs.length,
      itemBuilder: (_, int index) {
        final Map<String, dynamic> item = mcqs[index];
        final List<dynamic> options = item['options'] ?? <dynamic>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Q${index + 1}: ${item['question'] ?? 'Question'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(options.length, (int optionIndex) {
                  final String optionLabel = String.fromCharCode(65 + optionIndex);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('$optionLabel. ${options[optionIndex]}'),
                  );
                }),
                const SizedBox(height: 10),
                Text(
                  'Answer: ${item['answer'] ?? 'Not provided'}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildQuizTab() {
    if (quizPrompts.isEmpty) {
      return buildEmptyState('No quiz prompts returned by Gemini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quizPrompts.length,
      itemBuilder: (_, int index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.quiz_rounded),
            title: Text('Quiz Prompt ${index + 1}'),
            subtitle: Text(quizPrompts[index]),
          ),
        );
      },
    );
  }

  Widget buildQaTab() {
    if (qaItems.isEmpty) {
      return buildEmptyState('No questions and answers returned by Gemini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: qaItems.length,
      itemBuilder: (_, int index) {
        final Map<String, dynamic> item = qaItems[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.question_answer_rounded),
            title: Text(item['question'] ?? 'Question'),
            subtitle: Text(item['answer'] ?? 'Answer not available'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTab,
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Material'),
          actions: <Widget>[
            IconButton(
              onPressed: generateStudyMaterial,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Notes'),
              Tab(text: 'MCQs'),
              Tab(text: 'Quiz'),
              Tab(text: 'Q&A'),
            ],
          ),
        ),
        body: isLoading
            ? buildLoadingState()
            : errorMessage != null
                ? buildErrorState()
                : TabBarView(
                    children: <Widget>[
                      buildNotesTab(),
                      buildMcqsTab(),
                      buildQuizTab(),
                      buildQaTab(),
                    ],
                  ),
      ),
    );
  }
}
