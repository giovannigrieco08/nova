// Data Model: ReportModel
// Feature: 003-events-feed
// Purpose: Data layer model for event reports (moderation)

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'report_model.g.dart';

@HiveType(typeId: 7) // Hive type adapter ID
@JsonSerializable()
class ReportModel {
  @HiveField(0)
  @JsonKey(name: 'id')
  final String id;

  @HiveField(1)
  @JsonKey(name: 'event_id')
  final String eventId;

  @HiveField(2)
  @JsonKey(name: 'reporter_id')
  final String reporterId;

  @HiveField(3)
  @JsonKey(name: 'reason')
  final String reason; // inappropriate, spam, harassment, other

  @HiveField(4)
  @JsonKey(name: 'explanation')
  final String explanation;

  @HiveField(5)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @HiveField(6)
  @JsonKey(name: 'reviewed')
  final bool reviewed;

  ReportModel({
    required this.id,
    required this.eventId,
    required this.reporterId,
    required this.reason,
    required this.explanation,
    required this.createdAt,
    this.reviewed = false,
  });

  /// JSON deserialization (from Supabase REST API)
  factory ReportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$ReportModelToJson(this);

  /// Create new report (for submission)
  factory ReportModel.create({
    required String eventId,
    required String reporterId,
    required String reason,
    required String explanation,
  }) {
    return ReportModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
      eventId: eventId,
      reporterId: reporterId,
      reason: reason,
      explanation: explanation,
      createdAt: DateTime.now(),
      reviewed: false,
    );
  }

  /// Validate reason is allowed
  static bool isValidReason(String reason) {
    return ['inappropriate', 'spam', 'harassment', 'other'].contains(reason);
  }

  /// Get user-friendly reason text
  String get reasonText {
    switch (reason) {
      case 'inappropriate':
        return 'Inappropriate Content';
      case 'spam':
        return 'Spam';
      case 'harassment':
        return 'Harassment';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  /// CopyWith for partial updates
  ReportModel copyWith({
    String? id,
    String? eventId,
    String? reporterId,
    String? reason,
    String? explanation,
    DateTime? createdAt,
    bool? reviewed,
  }) {
    return ReportModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      reporterId: reporterId ?? this.reporterId,
      reason: reason ?? this.reason,
      explanation: explanation ?? this.explanation,
      createdAt: createdAt ?? this.createdAt,
      reviewed: reviewed ?? this.reviewed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReportModel(id: $id, eventId: $eventId, reason: $reason, reviewed: $reviewed)';
  }
}
