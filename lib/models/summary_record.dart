class SummaryRecord {
  const SummaryRecord({
    required this.id,
    required this.sourceUrl,
    required this.summaryType,
    required this.originalSummary,
    required this.currentSummary,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.isFavorite,
  });

  final String id;
  final String sourceUrl;
  final String summaryType;
  final String originalSummary;
  final String currentSummary;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  factory SummaryRecord.fromJson(Map<String, dynamic> json) {
    return SummaryRecord(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      summaryType: json['summaryType']?.toString() ?? 'short',
      originalSummary: json['originalSummary']?.toString() ?? '',
      currentSummary:
          json['currentSummary']?.toString() ?? json['originalSummary']?.toString() ?? '',
      language: json['language']?.toString() ?? 'English',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceUrl': sourceUrl,
      'summaryType': summaryType,
      'originalSummary': originalSummary,
      'currentSummary': currentSummary,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  SummaryRecord copyWith({
    String? id,
    String? sourceUrl,
    String? summaryType,
    String? originalSummary,
    String? currentSummary,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return SummaryRecord(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      summaryType: summaryType ?? this.summaryType,
      originalSummary: originalSummary ?? this.originalSummary,
      currentSummary: currentSummary ?? this.currentSummary,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

