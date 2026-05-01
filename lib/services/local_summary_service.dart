import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/summary_record.dart';
import 'local_session_service.dart';

class LocalSummaryService {
  static Future<List<SummaryRecord>> getRecords() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _migrateLegacyData(prefs);

    final String? raw = prefs.getString(LocalSessionService.summaryRecordsKey);
    if (raw == null || raw.isEmpty) {
      return <SummaryRecord>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final List<SummaryRecord> records = decoded
        .whereType<Map<String, dynamic>>()
        .map(SummaryRecord.fromJson)
        .toList()
      ..sort((SummaryRecord a, SummaryRecord b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  static Future<void> saveRecord(SummaryRecord record) async {
    final List<SummaryRecord> records = await getRecords();
    final int existingIndex = records.indexWhere((SummaryRecord item) => item.id == record.id);

    if (existingIndex >= 0) {
      records[existingIndex] = record.copyWith(updatedAt: DateTime.now());
    } else {
      records.insert(0, record.copyWith(updatedAt: DateTime.now()));
    }

    await _persist(records);
    await markLatest(record.id);
  }

  static Future<SummaryRecord> createGeneratedRecord({
    required String sourceUrl,
    required String summaryType,
    required String summary,
  }) async {
    final DateTime now = DateTime.now();
    final SummaryRecord record = SummaryRecord(
      id: now.microsecondsSinceEpoch.toString(),
      sourceUrl: sourceUrl,
      summaryType: summaryType,
      originalSummary: summary,
      currentSummary: summary,
      language: 'English',
      createdAt: now,
      updatedAt: now,
      isFavorite: false,
    );

    await saveRecord(record);
    return record;
  }

  static Future<SummaryRecord?> getRecordById(String id) async {
    final List<SummaryRecord> records = await getRecords();
    try {
      return records.firstWhere((SummaryRecord record) => record.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteRecord(String id) async {
    final List<SummaryRecord> records = await getRecords();
    records.removeWhere((SummaryRecord record) => record.id == id);
    await _persist(records);
  }

  static Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(LocalSessionService.summaryRecordsKey);
    await prefs.remove(LocalSessionService.latestSummaryIdKey);
    await prefs.remove(LocalSessionService.latestSummaryKey);
  }

  static Future<void> toggleFavorite(String id) async {
    final List<SummaryRecord> records = await getRecords();
    final int index = records.indexWhere((SummaryRecord record) => record.id == id);
    if (index < 0) {
      return;
    }

    records[index] = records[index].copyWith(
      isFavorite: !records[index].isFavorite,
      updatedAt: DateTime.now(),
    );
    await _persist(records);
  }

  static Future<void> updateCurrentSummary({
    required String id,
    required String summary,
    required String language,
  }) async {
    final List<SummaryRecord> records = await getRecords();
    final int index = records.indexWhere((SummaryRecord record) => record.id == id);
    if (index < 0) {
      return;
    }

    records[index] = records[index].copyWith(
      currentSummary: summary,
      language: language,
      updatedAt: DateTime.now(),
    );
    await _persist(records);
  }

  static Future<void> replaceWithRegenerated({
    required String id,
    required String summary,
  }) async {
    final List<SummaryRecord> records = await getRecords();
    final int index = records.indexWhere((SummaryRecord record) => record.id == id);
    if (index < 0) {
      return;
    }

    records[index] = records[index].copyWith(
      originalSummary: summary,
      currentSummary: summary,
      language: 'English',
      updatedAt: DateTime.now(),
    );
    await _persist(records);
  }

  static Future<SummaryRecord?> latestRecord() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? latestId = prefs.getString(LocalSessionService.latestSummaryIdKey);
    final List<SummaryRecord> records = await getRecords();

    if (latestId == null || latestId.isEmpty) {
      return records.isEmpty ? null : records.first;
    }

    final SummaryRecord? record = await getRecordById(latestId);
    return record ?? (records.isEmpty ? null : records.first);
  }

  static Future<void> markLatest(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalSessionService.latestSummaryIdKey, id);
    final SummaryRecord? record = await getRecordById(id);
    if (record != null) {
      await prefs.setString(LocalSessionService.latestSummaryKey, record.currentSummary);
    }
  }

  static Future<void> _persist(List<SummaryRecord> records) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(records.map((SummaryRecord item) => item.toJson()).toList());
    await prefs.setString(LocalSessionService.summaryRecordsKey, raw);
    if (records.isNotEmpty) {
      await prefs.setString(LocalSessionService.latestSummaryIdKey, records.first.id);
      await prefs.setString(LocalSessionService.latestSummaryKey, records.first.currentSummary);
    } else {
      await prefs.remove(LocalSessionService.latestSummaryIdKey);
      await prefs.remove(LocalSessionService.latestSummaryKey);
    }
  }

  static Future<void> _migrateLegacyData(SharedPreferences prefs) async {
    if (prefs.containsKey(LocalSessionService.summaryRecordsKey)) {
      return;
    }

    final List<String> history = prefs.getStringList(LocalSessionService.historyKey) ?? <String>[];
    final List<String> favorites =
        prefs.getStringList(LocalSessionService.favoritesKey) ?? <String>[];

    if (history.isEmpty && favorites.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    final List<String> combined = <String>[
      ...history,
      ...favorites.where((String item) => !history.contains(item)),
    ];

    final List<SummaryRecord> migrated = combined.asMap().entries.map((entry) {
      final int index = entry.key;
      final String text = entry.value;
      final DateTime createdAt = now.subtract(Duration(minutes: index));
      return SummaryRecord(
        id: createdAt.microsecondsSinceEpoch.toString(),
        sourceUrl: '',
        summaryType: 'short',
        originalSummary: text,
        currentSummary: text,
        language: 'English',
        createdAt: createdAt,
        updatedAt: createdAt,
        isFavorite: favorites.contains(text),
      );
    }).toList();

    await _persist(migrated);
  }
}
