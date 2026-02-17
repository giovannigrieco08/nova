import 'package:flutter/foundation.dart';

/// Report categories as defined in the database
enum ReportCategory {
  spam('spam', 'Spam'),
  offensiveContent('offensive_content', 'Contenuto offensivo'),
  bullying('bullying', 'Bullismo'),
  inappropriate('inappropriate', 'Contenuto inappropriato'),
  other('other', 'Altro');

  const ReportCategory(this.value, this.displayName);
  final String value;
  final String displayName;

  static ReportCategory fromString(String value) {
    return ReportCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportCategory.other,
    );
  }
}

/// Report status enum
enum ReportStatus {
  pending('pending', 'In attesa'),
  reviewed('reviewed', 'Esaminato'),
  dismissed('dismissed', 'Archiviato'),
  actionTaken('action_taken', 'Azione intrapresa');

  const ReportStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

/// Content types that can be reported
enum ReportableContentType {
  event('event'),
  comment('comment'),
  chatMessage('chat_message'),
  profile('profile');

  const ReportableContentType(this.value);
  final String value;

  static ReportableContentType fromString(String value) {
    return ReportableContentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportableContentType.event,
    );
  }
}

/// Report model representing a content report
@immutable
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    required this.category,
    this.note,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.actionTaken,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final ReportableContentType contentType;
  final String contentId;
  final ReportCategory category;
  final String? note;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? actionTaken;
  final DateTime createdAt;

  /// Create from Supabase JSON response
  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      contentType: ReportableContentType.fromString(json['content_type'] as String),
      contentId: json['content_id'] as String,
      category: ReportCategory.fromString(json['category'] as String),
      note: json['note'] as String?,
      status: ReportStatus.fromString(json['status'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      actionTaken: json['action_taken'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'reporter_id': reporterId,
      'content_type': contentType.value,
      'content_id': contentId,
      'category': category.value,
      if (note != null) 'note': note,
    };
  }

  /// Create a copy with modified fields
  Report copyWith({
    String? id,
    String? reporterId,
    ReportableContentType? contentType,
    String? contentId,
    ReportCategory? category,
    String? note,
    ReportStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? actionTaken,
    DateTime? createdAt,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      category: category ?? this.category,
      note: note ?? this.note,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      actionTaken: actionTaken ?? this.actionTaken,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Report && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
