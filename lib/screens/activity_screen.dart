import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_summary_service.dart';
import '../services/local_session_service.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int historyCount = 0;
  int favoritesCount = 0;
  int usageCount = 0;
  DateTime? lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final records = await LocalSummaryService.getRecords();

    if (!mounted) {
      return;
    }

    setState(() {
      historyCount = records.length;
      favoritesCount = records.where((record) => record.isFavorite).length;
      usageCount = prefs.getInt(LocalSessionService.usageKey) ?? 0;
      lastUpdatedAt = records.isEmpty ? null : records.first.updatedAt;
    });
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Activity',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Review your recent summaries, favorites, and study progress.',
                ),
                if (lastUpdatedAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Last activity: ${MaterialLocalizations.of(context).formatFullDate(lastUpdatedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 520;
                    final double cardWidth = compact
                        ? (constraints.maxWidth - 12) / 2
                        : (constraints.maxWidth - 24) / 3;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        statCard(
                          title: 'Saved',
                          value: '$historyCount',
                          icon: Icons.auto_stories_rounded,
                          width: cardWidth,
                        ),
                        statCard(
                          title: 'Favorites',
                          value: '$favoritesCount',
                          icon: Icons.star_rounded,
                          width: cardWidth,
                        ),
                        statCard(
                          title: 'Requests',
                          value: '$usageCount',
                          icon: Icons.insights_rounded,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Search by text, filter by date, and update summaries directly from the tabs below.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'History'),
                    Tab(text: 'Favorites'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                HistoryScreen(onChanged: loadStats),
                FavoritesScreen(onChanged: loadStats),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
