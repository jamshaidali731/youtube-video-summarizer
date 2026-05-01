import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/summary_record.dart';
import '../../services/api_service.dart';
import '../../services/local_session_service.dart';
import '../../services/local_summary_service.dart';
import '../result_screen.dart';
import '../subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController urlController = TextEditingController();

  String selectedType = 'short';
  bool loading = false;
  int usageCount = 0;
  final int maxFreeUses = 10;
  SummaryRecord? latestRecord;

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    loadUsage();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadUsage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SummaryRecord? latest = await LocalSummaryService.latestRecord();
    if (!mounted) {
      return;
    }

    setState(() {
      usageCount = prefs.getInt(LocalSessionService.usageKey) ?? 0;
      latestRecord = latest;
    });
  }

  Future<void> saveUsage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LocalSessionService.usageKey, usageCount);
  }

  Future<void> showPremiumDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limit Reached'),
          content: const Text(
            'Your 10 free uses are finished. Upgrade to Premium to continue.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  this.context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: const Text('Choose Plan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> generateSummary() async {
    FocusScope.of(context).unfocus();

    final String url = urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter YouTube URL')),
      );
      return;
    }

    if (usageCount >= maxFreeUses) {
      await showPremiumDialog();
      return;
    }

    setState(() => loading = true);
    _animationController.repeat();

    try {
      final ApiResponse result = await ApiService.summarizeVideo(
        url: url,
        type: selectedType,
      );

      if (!mounted) {
        return;
      }

      _animationController.stop();
      setState(() {
        loading = false;
        if (result.success) {
          usageCount++;
        }
      });

      await saveUsage();

      if (!result.success || (result.data ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      final SummaryRecord record = await LocalSummaryService.createGeneratedRecord(
        sourceUrl: url,
        summaryType: selectedType,
        summary: result.data!,
      );

      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            summary: record.currentSummary,
            recordId: record.id,
            sourceUrl: record.sourceUrl,
            summaryType: record.summaryType,
          ),
        ),
      );
      await loadUsage();
    } catch (e) {
      _animationController.stop();
      if (!mounted) {
        return;
      }

      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remaining = (maxFreeUses - usageCount).clamp(0, maxFreeUses);

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Summarize YouTube videos, translate them, and build study-ready notes in one place.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFF4D4D), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (_, Widget? child) {
                            return Transform.rotate(
                              angle: _animationController.value * 6.28,
                              child: child,
                            );
                          },
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                        const Spacer(),
                        Chip(
                          label: Text(
                            '$remaining free uses left',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.white24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AI-Powered Video Study Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paste a YouTube link, choose summary length, and generate study-ready content.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: usageCount / maxFreeUses,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'YouTube URL',
                  prefixIcon: Icon(Icons.link_rounded),
                  hintText: 'Paste your video link here',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Short'),
                    selected: selectedType == 'short',
                    onSelected: (_) {
                      setState(() => selectedType = 'short');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Detailed'),
                    selected: selectedType == 'detailed',
                    onSelected: (_) {
                      setState(() => selectedType = 'detailed');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : generateSummary,
                  child: const Text('Generate Summary'),
                ),
              ),
              if (latestRecord != null) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.history_rounded),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Latest Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (latestRecord == null) {
                                return;
                              }

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ResultScreen(
                                    summary: latestRecord!.currentSummary,
                                    recordId: latestRecord!.id,
                                    sourceUrl: latestRecord!.sourceUrl,
                                    summaryType: latestRecord!.summaryType,
                                  ),
                                ),
                              );
                              await loadUsage();
                            },
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        latestRecord!.currentSummary,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${latestRecord!.summaryType == 'detailed' ? 'Detailed' : 'Short'} | ${latestRecord!.language}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Premium Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Unlock unlimited summaries and study tools.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                      },
                      child: const Text('View Plans'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (loading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Please wait...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Generating your AI summary'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
