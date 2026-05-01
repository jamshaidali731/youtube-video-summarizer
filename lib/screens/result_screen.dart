import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/summary_record.dart';
import '../services/api_service.dart';
import '../services/gemini_translation_service.dart';
import '../services/local_summary_service.dart';
import 'study_material_screen.dart';

enum _ResultAction {
  edit,
  restore,
  regenerate,
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.summary,
    this.recordId,
    this.sourceUrl,
    this.summaryType,
  });

  final String summary;
  final String? recordId;
  final String? sourceUrl;
  final String? summaryType;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final FlutterTts tts = FlutterTts();

  bool isPlaying = false;
  bool isFavorite = false;
  bool isTranslating = false;
  bool isRegenerating = false;
  bool isLoadingRecord = false;

  SummaryRecord? record;
  String currentSummary = '';
  String translatedText = '';
  String selectedLanguage = 'English';
  String summaryType = 'short';
  String sourceUrl = '';

  @override
  void initState() {
    super.initState();
    currentSummary = widget.summary;
    translatedText = widget.summary;
    summaryType = widget.summaryType ?? 'short';
    sourceUrl = widget.sourceUrl ?? '';
    loadRecord();
  }

  String get activeText => translatedText.isEmpty ? currentSummary : translatedText;

  bool get hasRecord => widget.recordId != null && widget.recordId!.isNotEmpty;

  bool get canRegenerate => sourceUrl.trim().isNotEmpty;

  Future<void> loadRecord() async {
    if (!hasRecord) {
      return;
    }

    setState(() {
      isLoadingRecord = true;
    });

    final SummaryRecord? loadedRecord = await LocalSummaryService.getRecordById(widget.recordId!);
    if (loadedRecord != null) {
      await LocalSummaryService.markLatest(widget.recordId!);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      record = loadedRecord;
      currentSummary = loadedRecord?.currentSummary ?? widget.summary;
      translatedText = loadedRecord?.currentSummary ?? widget.summary;
      selectedLanguage = loadedRecord?.language ?? 'English';
      summaryType = loadedRecord?.summaryType ?? summaryType;
      sourceUrl = loadedRecord?.sourceUrl ?? sourceUrl;
      isFavorite = loadedRecord?.isFavorite ?? false;
      isLoadingRecord = false;
    });
  }

  Future<void> refreshRecord() async {
    if (!hasRecord) {
      return;
    }

    final SummaryRecord? updatedRecord = await LocalSummaryService.getRecordById(widget.recordId!);
    if (!mounted || updatedRecord == null) {
      return;
    }

    setState(() {
      record = updatedRecord;
      currentSummary = updatedRecord.currentSummary;
      translatedText = updatedRecord.currentSummary;
      selectedLanguage = updatedRecord.language;
      summaryType = updatedRecord.summaryType;
      sourceUrl = updatedRecord.sourceUrl;
      isFavorite = updatedRecord.isFavorite;
    });
  }

  Future<void> persistCurrentText({
    required String summary,
    required String language,
  }) async {
    if (!hasRecord) {
      return;
    }

    await LocalSummaryService.updateCurrentSummary(
      id: widget.recordId!,
      summary: summary,
      language: language,
    );
    await LocalSummaryService.markLatest(widget.recordId!);
    await refreshRecord();
  }

  Future<void> playTTS() async {
    await tts.speak(activeText);
    if (!mounted) {
      return;
    }

    setState(() {
      isPlaying = true;
    });
  }

  Future<void> stopTTS() async {
    await tts.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      isPlaying = false;
    });
  }

  void copyText() {
    Clipboard.setData(ClipboardData(text: activeText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied successfully')),
    );
  }

  void shareText() {
    Share.share(activeText);
  }

  Future<void> toggleFavorite() async {
    if (!hasRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save a generated summary first to favorite it')),
      );
      return;
    }

    await LocalSummaryService.toggleFavorite(widget.recordId!);
    await refreshRecord();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? 'Added to favorites' : 'Removed from favorites',
        ),
      ),
    );
  }

  Future<void> downloadFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String fileName =
        'summary_${DateTime.now().millisecondsSinceEpoch}_${selectedLanguage.toLowerCase()}.txt';
    final File file = File('${dir.path}/$fileName');
    await file.writeAsString(activeText);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved at: ${file.path}')),
    );
  }

  Future<void> editSummary() async {
    final TextEditingController controller = TextEditingController(text: activeText);

    final String? updatedSummary = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Summary'),
          content: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'Refine or edit your summary here',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (updatedSummary == null || updatedSummary.isEmpty) {
      return;
    }

    setState(() {
      currentSummary = updatedSummary;
      translatedText = updatedSummary;
    });

    await persistCurrentText(
      summary: updatedSummary,
      language: selectedLanguage,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary updated successfully')),
    );
  }

  Future<void> restoreOriginal() async {
    final String restoredText = record?.originalSummary ?? widget.summary;

    setState(() {
      currentSummary = restoredText;
      translatedText = restoredText;
      selectedLanguage = 'English';
    });

    await persistCurrentText(
      summary: restoredText,
      language: 'English',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Original summary restored')),
    );
  }

  Future<void> regenerateSummary() async {
    if (!canRegenerate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original YouTube link not found for this summary')),
      );
      return;
    }

    setState(() {
      isRegenerating = true;
    });

    final ApiResponse response = await ApiService.summarizeVideo(
      url: sourceUrl,
      type: summaryType,
    );

    if (response.success && (response.data ?? '').isNotEmpty) {
      setState(() {
        currentSummary = response.data!;
        translatedText = response.data!;
        selectedLanguage = 'English';
      });

      if (hasRecord) {
        await LocalSummaryService.replaceWithRegenerated(
          id: widget.recordId!,
          summary: response.data!,
        );
        await LocalSummaryService.markLatest(widget.recordId!);
        await refreshRecord();
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isRegenerating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success ? 'Summary regenerated successfully' : response.message,
        ),
      ),
    );
  }

  Future<void> translateSummary(String language) async {
    if (language == selectedLanguage && activeText.trim().isNotEmpty) {
      return;
    }

    if (language == 'English') {
      final String englishText = (record?.originalSummary ?? '').isNotEmpty
          ? record!.originalSummary
          : widget.summary;

      setState(() {
        selectedLanguage = 'English';
        currentSummary = englishText;
        translatedText = englishText;
      });

      await persistCurrentText(
        summary: englishText,
        language: 'English',
      );
      return;
    }

    setState(() {
      selectedLanguage = language;
      isTranslating = true;
    });

    try {
      final String translated = await GeminiTranslationService.translateText(
        text: currentSummary,
        targetLanguage: language,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        translatedText = translated;
        currentSummary = translated;
        selectedLanguage = language;
        isTranslating = false;
      });

      await persistCurrentText(
        summary: translated,
        language: language,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isTranslating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    }
  }

  Future<void> showTranslationDialog() async {
    final String? language = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('English'),
                onTap: () => Navigator.pop(context, 'English'),
              ),
              ListTile(
                title: const Text('Urdu'),
                onTap: () => Navigator.pop(context, 'Urdu'),
              ),
              ListTile(
                title: const Text('Hindi'),
                onTap: () => Navigator.pop(context, 'Hindi'),
              ),
              ListTile(
                title: const Text('Arabic'),
                onTap: () => Navigator.pop(context, 'Arabic'),
              ),
            ],
          ),
        );
      },
    );

    if (language == null) {
      return;
    }

    await translateSummary(language);
  }

  Future<void> handleResultAction(_ResultAction action) async {
    switch (action) {
      case _ResultAction.edit:
        await editSummary();
        break;
      case _ResultAction.restore:
        await restoreOriginal();
        break;
      case _ResultAction.regenerate:
        await regenerateSummary();
        break;
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Widget actionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget buildInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primary,
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Summary Workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isTranslating || isRegenerating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                backgroundColor: Colors.white12,
                label: Text(
                  selectedLanguage,
                  style: const TextStyle(color: Colors.white),
                ),
                avatar: const Icon(Icons.translate_rounded, color: Colors.white, size: 16),
              ),
              Chip(
                backgroundColor: Colors.white12,
                label: Text(
                  summaryType == 'detailed' ? 'Detailed summary' : 'Short summary',
                  style: const TextStyle(color: Colors.white),
                ),
                avatar: const Icon(Icons.notes_rounded, color: Colors.white, size: 16),
              ),
              Chip(
                backgroundColor: Colors.white12,
                label: Text(
                  isFavorite ? 'Favorite' : 'Not favorite',
                  style: const TextStyle(color: Colors.white),
                ),
                avatar: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            record == null
                ? 'Open this summary, translate it, edit it, and generate study tools.'
                : 'Updated ${formatDate(record?.updatedAt)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.description_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Current Summary',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: isTranslating ? null : showTranslationDialog,
                icon: const Icon(Icons.translate_rounded, size: 18),
                label: const Text('Translate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (record != null && sourceUrl.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                sourceUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (isTranslating)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Text(
            activeText,
            style: const TextStyle(fontSize: 16, height: 1.7),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary Result'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_rounded),
            onPressed: () => isPlaying ? stopTTS() : playTTS(),
          ),
          IconButton(
            icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: toggleFavorite,
          ),
          PopupMenuButton<_ResultAction>(
            onSelected: handleResultAction,
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<_ResultAction>>[
                const PopupMenuItem<_ResultAction>(
                  value: _ResultAction.edit,
                  child: Text('Edit / Update'),
                ),
                const PopupMenuItem<_ResultAction>(
                  value: _ResultAction.restore,
                  child: Text('Restore Original'),
                ),
                PopupMenuItem<_ResultAction>(
                  value: _ResultAction.regenerate,
                  enabled: canRegenerate,
                  child: const Text('Regenerate'),
                ),
              ];
            },
          ),
        ],
      ),
      body: isLoadingRecord
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: <Widget>[
                ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: <Widget>[
                    buildInfoCard(),
                    buildSummaryCard(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          actionButton('Copy', Icons.copy_rounded, copyText),
                          actionButton('Share', Icons.share_rounded, shareText),
                          actionButton('Download', Icons.download_rounded, downloadFile),
                          actionButton('Translate', Icons.translate_rounded, showTranslationDialog),
                          actionButton('Edit', Icons.edit_rounded, editSummary),
                          actionButton(
                            'Study Material',
                            Icons.school_rounded,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudyMaterialScreen(summary: activeText),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isRegenerating)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CircularProgressIndicator(),
                              SizedBox(height: 14),
                              Text(
                                'Regenerating summary...',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text('Please wait while the latest summary is prepared.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
