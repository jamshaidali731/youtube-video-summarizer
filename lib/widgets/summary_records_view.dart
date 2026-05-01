import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/summary_record.dart';
import '../screens/result_screen.dart';
import '../services/api_service.dart';
import '../services/local_summary_service.dart';

enum _SummaryDateFilter {
  all,
  today,
  week,
  month,
}

enum _SummarySortOption {
  latestUpdated,
  oldestUpdated,
  latestCreated,
  oldestCreated,
}

enum _RecordAction {
  open,
  edit,
  favorite,
  regenerate,
  delete,
}

class SummaryRecordsView extends StatefulWidget {
  const SummaryRecordsView({
    super.key,
    required this.favoritesOnly,
    this.onChanged,
  });

  final bool favoritesOnly;
  final VoidCallback? onChanged;

  @override
  State<SummaryRecordsView> createState() => _SummaryRecordsViewState();
}

class _SummaryRecordsViewState extends State<SummaryRecordsView> {
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  String? busyRecordId;
  String query = '';
  _SummaryDateFilter dateFilter = _SummaryDateFilter.all;
  _SummarySortOption sortOption = _SummarySortOption.latestUpdated;
  List<SummaryRecord> records = <SummaryRecord>[];

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadRecords() async {
    final List<SummaryRecord> loadedRecords = await LocalSummaryService.getRecords();

    if (!mounted) {
      return;
    }

    setState(() {
      records = loadedRecords;
      loading = false;
    });
  }

  List<SummaryRecord> get visibleRecords {
    List<SummaryRecord> filtered = widget.favoritesOnly
        ? records.where((SummaryRecord record) => record.isFavorite).toList()
        : List<SummaryRecord>.from(records);

    if (query.trim().isNotEmpty) {
      final String normalizedQuery = query.trim().toLowerCase();
      filtered = filtered.where((SummaryRecord record) {
        final String haystack = <String>[
          record.currentSummary,
          record.originalSummary,
          record.sourceUrl,
          record.language,
          record.summaryType,
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      }).toList();
    }

    filtered = filtered.where((SummaryRecord record) {
      final DateTime date = record.updatedAt;
      final DateTime now = DateTime.now();

      switch (dateFilter) {
        case _SummaryDateFilter.today:
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case _SummaryDateFilter.week:
          return now.difference(date).inDays < 7;
        case _SummaryDateFilter.month:
          return now.difference(date).inDays < 30;
        case _SummaryDateFilter.all:
          return true;
      }
    }).toList();

    filtered.sort((SummaryRecord a, SummaryRecord b) {
      switch (sortOption) {
        case _SummarySortOption.oldestUpdated:
          return a.updatedAt.compareTo(b.updatedAt);
        case _SummarySortOption.latestCreated:
          return b.createdAt.compareTo(a.createdAt);
        case _SummarySortOption.oldestCreated:
          return a.createdAt.compareTo(b.createdAt);
        case _SummarySortOption.latestUpdated:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });

    return filtered;
  }

  Future<void> openRecord(SummaryRecord record) async {
    await LocalSummaryService.markLatest(record.id);

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

    await loadRecords();
    widget.onChanged?.call();
  }

  Future<void> editRecord(SummaryRecord record) async {
    final TextEditingController controller = TextEditingController(
      text: record.currentSummary,
    );

    final String? updatedSummary = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Summary'),
          content: TextField(
            controller: controller,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Edit your summary text',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (updatedSummary == null || updatedSummary.isEmpty) {
      return;
    }

    await LocalSummaryService.updateCurrentSummary(
      id: record.id,
      summary: updatedSummary,
      language: record.language,
    );
    await LocalSummaryService.markLatest(record.id);
    await loadRecords();
    widget.onChanged?.call();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary updated successfully')),
    );
  }

  Future<void> toggleFavorite(SummaryRecord record) async {
    await LocalSummaryService.toggleFavorite(record.id);
    await loadRecords();
    widget.onChanged?.call();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          record.isFavorite ? 'Removed from favorites' : 'Added to favorites',
        ),
      ),
    );
  }

  Future<void> regenerateRecord(SummaryRecord record) async {
    if (record.sourceUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source URL not available for regeneration')),
      );
      return;
    }

    setState(() {
      busyRecordId = record.id;
    });

    final ApiResponse response = await ApiService.summarizeVideo(
      url: record.sourceUrl,
      type: record.summaryType,
    );

    if (response.success && (response.data ?? '').isNotEmpty) {
      await LocalSummaryService.replaceWithRegenerated(
        id: record.id,
        summary: response.data!,
      );
      await LocalSummaryService.markLatest(record.id);
      await loadRecords();
      widget.onChanged?.call();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      busyRecordId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success ? 'Summary regenerated successfully' : response.message,
        ),
      ),
    );
  }

  Future<void> deleteRecord(SummaryRecord record) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Summary'),
          content: const Text('This summary will be removed from history and favorites.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await LocalSummaryService.deleteRecord(record.id);
    await loadRecords();
    widget.onChanged?.call();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary deleted')),
    );
  }

  Future<void> handleAction(_RecordAction action, SummaryRecord record) async {
    switch (action) {
      case _RecordAction.open:
        await openRecord(record);
        break;
      case _RecordAction.edit:
        await editRecord(record);
        break;
      case _RecordAction.favorite:
        await toggleFavorite(record);
        break;
      case _RecordAction.regenerate:
        await regenerateRecord(record);
        break;
      case _RecordAction.delete:
        await deleteRecord(record);
        break;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String get countLabel {
    final int count = visibleRecords.length;
    if (widget.favoritesOnly) {
      return '$count favorite ${count == 1 ? 'item' : 'items'}';
    }
    return '$count summary ${count == 1 ? 'item' : 'items'}';
  }

  String get sortLabel {
    switch (sortOption) {
      case _SummarySortOption.oldestUpdated:
        return 'Oldest updated';
      case _SummarySortOption.latestCreated:
        return 'Latest created';
      case _SummarySortOption.oldestCreated:
        return 'Oldest created';
      case _SummarySortOption.latestUpdated:
        return 'Latest updated';
    }
  }

  Widget buildEmptyState() {
    final bool hasFilters = query.trim().isNotEmpty || dateFilter != _SummaryDateFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              widget.favoritesOnly ? Icons.star_border_rounded : Icons.history_toggle_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No matching summaries found'
                  : widget.favoritesOnly
                      ? 'No favorites saved yet'
                      : 'No summary history found yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try another search or date filter.'
                  : widget.favoritesOnly
                      ? 'Save any summary as favorite and it will appear here.'
                      : 'Generate a summary from the dashboard and it will show up here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: searchController,
            onChanged: (String value) {
              setState(() {
                query = value;
              });
            },
            decoration: InputDecoration(
              hintText: widget.favoritesOnly
                  ? 'Search favorite summaries'
                  : 'Search summaries, language, or video URL',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          query = '';
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                buildDateChip(_SummaryDateFilter.all, 'All'),
                const SizedBox(width: 8),
                buildDateChip(_SummaryDateFilter.today, 'Today'),
                const SizedBox(width: 8),
                buildDateChip(_SummaryDateFilter.week, '7 days'),
                const SizedBox(width: 8),
                buildDateChip(_SummaryDateFilter.month, '30 days'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PopupMenuButton<_SummarySortOption>(
                onSelected: (_SummarySortOption value) {
                  setState(() {
                    sortOption = value;
                  });
                },
                itemBuilder: (BuildContext context) {
                  return const <PopupMenuEntry<_SummarySortOption>>[
                    PopupMenuItem<_SummarySortOption>(
                      value: _SummarySortOption.latestUpdated,
                      child: Text('Latest updated'),
                    ),
                    PopupMenuItem<_SummarySortOption>(
                      value: _SummarySortOption.oldestUpdated,
                      child: Text('Oldest updated'),
                    ),
                    PopupMenuItem<_SummarySortOption>(
                      value: _SummarySortOption.latestCreated,
                      child: Text('Latest created'),
                    ),
                    PopupMenuItem<_SummarySortOption>(
                      value: _SummarySortOption.oldestCreated,
                      child: Text('Oldest created'),
                    ),
                  ];
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.swap_vert_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(sortLabel),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDateChip(_SummaryDateFilter value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: dateFilter == value,
      onSelected: (_) {
        setState(() {
          dateFilter = value;
        });
      },
    );
  }

  Widget buildRecordCard(SummaryRecord record) {
    final bool isBusy = busyRecordId == record.id;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openRecord(record),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(
                          avatar: Icon(
                            record.summaryType == 'detailed'
                                ? Icons.article_rounded
                                : Icons.notes_rounded,
                            size: 16,
                          ),
                          label: Text(
                            record.summaryType == 'detailed' ? 'Detailed' : 'Short',
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.translate_rounded, size: 16),
                          label: Text(record.language),
                        ),
                        if (record.isFavorite)
                          const Chip(
                            avatar: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            label: Text('Favorite'),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_RecordAction>(
                    onSelected: (_RecordAction action) => handleAction(action, record),
                    itemBuilder: (BuildContext context) {
                      return <PopupMenuEntry<_RecordAction>>[
                        const PopupMenuItem<_RecordAction>(
                          value: _RecordAction.open,
                          child: Text('Open'),
                        ),
                        const PopupMenuItem<_RecordAction>(
                          value: _RecordAction.edit,
                          child: Text('Edit / Update'),
                        ),
                        PopupMenuItem<_RecordAction>(
                          value: _RecordAction.favorite,
                          child: Text(
                            record.isFavorite ? 'Remove favorite' : 'Add to favorites',
                          ),
                        ),
                        PopupMenuItem<_RecordAction>(
                          value: _RecordAction.regenerate,
                          enabled: record.sourceUrl.trim().isNotEmpty,
                          child: Text('Regenerate'),
                        ),
                        const PopupMenuItem<_RecordAction>(
                          value: _RecordAction.delete,
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                record.currentSummary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Updated ${formatDate(record.updatedAt)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created ${formatDate(record.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.sourceUrl.trim().isEmpty
                                ? 'Source URL not available'
                                : record.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isBusy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<SummaryRecord> items = visibleRecords;

    return Column(
      children: <Widget>[
        buildHeader(),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: loadRecords,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, int index) => buildRecordCard(items[index]),
                      ),
                    ),
        ),
      ],
    );
  }
}
