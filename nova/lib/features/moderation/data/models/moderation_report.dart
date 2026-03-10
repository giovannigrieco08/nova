// =====================================================================
// ModerationReport Model - Moderation Queue for User Reports
// =====================================================================
// Purpose: Model representing reports in moderation queue with user info
// =====================================================================

import 'package:flutter/foundation.dart';
import 'package:nova/features/safety/data/models/report.dart';

/// Report with additional context for moderation
@immutable
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    required this.category,
    this.note,
    required this.status,
    required this.createdAt,
    required this.hoursPending,
    required this.isUrgent,
    this.reporterName,
    this.reporterUsername,
    this.reportedUserId,
    this.reportedUserName,
    this.reportedUserUsername,
    this.reportedUserAvatarUrl,
  });

  final String id;
  final String reporterId;
  final ReportableContentType contentType;
  final String contentId;
  final ReportCategory category;
  final String? note;
  final ReportStatus status;
  final DateTime createdAt;
  final double hoursPending;
  final bool isUrgent;

  // Reporter info
  final String? reporterName;
  final String? reporterUsername;

  // Reported user info (for profile reports)
  final String? reportedUserId;
  final String? reportedUserName;
  final String? reportedUserUsername;
  final String? reportedUserAvatarUrl;

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>?;

    return ModerationReport(
      id: json['id'] as String,
      reporterId: reporter?['user_id'] as String? ?? '',
      contentType:
          ReportableContentType.fromString(json['content_type'] as String),
      contentId: json['content_id'] as String,
      category: ReportCategory.fromString(json['category'] as String),
      note: json['note'] as String?,
      status: ReportStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      hoursPending: (json['hours_pending'] as num?)?.toDouble() ?? 0,
      isUrgent: json['is_urgent'] as bool? ?? false,
      reporterName: reporter?['full_name'] as String?,
      reporterUsername: reporter?['username'] as String?,
      reportedUserId: json['reported_user_id'] as String?,
      reportedUserName: json['reported_user_name'] as String?,
      reportedUserUsername: json['reported_user_username'] as String?,
      reportedUserAvatarUrl: json['reported_user_avatar_url'] as String?,
    );
  }

  /// Get time since submission for display
  String get timeSinceSubmission {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minuto' : 'minuti'} fa';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'ora' : 'ore'} fa';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'giorno' : 'giorni'} fa';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'settimana' : 'settimane'} fa';
    }
  }

  /// Display name for the reported user
  String get reportedUserDisplayName {
    if (reportedUserName != null && reportedUserName!.isNotEmpty) {
      return reportedUserName!;
    }
    if (reportedUserUsername != null && reportedUserUsername!.isNotEmpty) {
      return '@$reportedUserUsername';
    }
    return 'Utente';
  }

  /// Display name for the content type
  String get contentTypeDisplayName {
    switch (contentType) {
      case ReportableContentType.event:
        return 'Evento';
      case ReportableContentType.comment:
        return 'Commento';
      case ReportableContentType.chatMessage:
        return 'Messaggio';
      case ReportableContentType.profile:
        return 'Profilo';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModerationReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
