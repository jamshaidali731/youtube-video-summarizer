import 'package:flutter/material.dart';

import '../models/summary_record.dart';
import '../services/local_summary_service.dart';
import 'study_material_screen.dart';

class StudyToolsHubScreen extends StatefulWidget {
  const StudyToolsHubScreen({super.key});

  @override
  State<StudyToolsHubScreen> createState() => _StudyToolsHubScreenState();
}

class _StudyToolsHubScreenState extends State<StudyToolsHubScreen> {
  SummaryRecord? latestRecord;

  @override
  void initState() {
    super.initState();
    loadLatestSummary();
  }

  Future<void> loadLatestSummary() async {
    final SummaryRecord? record = await LocalSummaryService.latestRecord();
    if (!mounted) {
      return;
    }

    setState(() {
      latestRecord = record;
    });
  }

  void openTools(int tabIndex) {
    if ((latestRecord?.currentSummary ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a summary first to use study tools')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyMaterialScreen(
          summary: latestRecord!.currentSummary,
          initialTab: tabIndex,
        ),
      ),
    );
  }

  Widget toolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Study Tools',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Turn your latest summary into notes, MCQs, quizzes, and quick revision answers.',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF111827), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Latest Summary Source',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  latestRecord == null
                      ? 'No summary is ready yet. Generate one from Dashboard first.'
                      : latestRecord!.currentSummary,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                if (latestRecord != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    '${latestRecord!.summaryType == 'detailed' ? 'Detailed' : 'Short'} | ${latestRecord!.language}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            childAspectRatio: 1.05,
            children: <Widget>[
              toolCard(
                title: 'Notes',
                subtitle: 'Condensed revision points for fast reading.',
                icon: Icons.notes_rounded,
                onTap: () => openTools(0),
              ),
              toolCard(
                title: 'MCQs',
                subtitle: 'Multiple-choice practice from your summary.',
                icon: Icons.quiz_rounded,
                onTap: () => openTools(1),
              ),
              toolCard(
                title: 'Quiz',
                subtitle: 'Quick prompts to test your understanding.',
                icon: Icons.fact_check_rounded,
                onTap: () => openTools(2),
              ),
              toolCard(
                title: 'Q&A',
                subtitle: 'Short questions with direct answers.',
                icon: Icons.question_answer_rounded,
                onTap: () => openTools(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
