/// CommentReportReason Enum
///
/// Predefined reasons for reporting a comment.
enum CommentReportReason {
  spam('spam', 'Spam'),
  inappropriate('inappropriate', 'Contenuto inappropriato'),
  bullying('bullying', 'Bullismo/molestie'),
  offTopic('off_topic', 'Off-topic'),
  other('other', 'Altro');

  final String value;
  final String displayName;

  const CommentReportReason(this.value, this.displayName);

  static CommentReportReason fromValue(String value) {
    return CommentReportReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => CommentReportReason.other,
    );
  }
}

/// CommentReportStatus Enum
///
/// Status of a report in the moderation workflow.
enum CommentReportStatus {
  pending('pending', 'In attesa'),
  reviewed('reviewed', 'Revisionato'),
  dismissed('dismissed', 'Respinto');

  final String value;
  final String displayName;

  const CommentReportStatus(this.value, this.displayName);

  static CommentReportStatus fromValue(String value) {
    return CommentReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CommentReportStatus.pending,
    );
  }
}

/// CommentReport Entity
///
/// Business entity representing a user-submitted report for inappropriate content.
/// Includes moderation workflow state and optional details.
class CommentReport {
  final String id;
  final String commentId;
  final String reporterUserId;
  final CommentReportReason reason;
  final String? details; // Optional elaboration (max 500 chars)
  final CommentReportStatus status;
  final String? reviewedByModeratorId;
  final DateTime? reviewedAt;
  final String? moderatorNotes;
  final DateTime createdAt;

  const CommentReport({
    required this.id,
    required this.commentId,
    required this.reporterUserId,
    required this.reason,
    this.details,
    this.status = CommentReportStatus.pending,
    this.reviewedByModeratorId,
    this.reviewedAt,
    this.moderatorNotes,
    required this.createdAt,
  });

  /// Returns true if this report is still pending review
  bool get isPending => status == CommentReportStatus.pending;

  /// Returns true if this report has been reviewed
  bool get isReviewed => status == CommentReportStatus.reviewed;

  /// Returns true if this report was dismissed
  bool get isDismissed => status == CommentReportStatus.dismissed;

  /// Returns formatted reason for display in UI
  String get displayReason => reason.displayName;

  /// Returns formatted status for display in UI
  String get displayStatus => status.displayName;

  /// Returns true if this report was submitted by the given user
  bool isReportedBy(String userId) => reporterUserId == userId;

  CommentReport copyWith({
    String? id,
    String? commentId,
    String? reporterUserId,
    CommentReportReason? reason,
    String? details,
    CommentReportStatus? status,
    String? reviewedByModeratorId,
    DateTime? reviewedAt,
    String? moderatorNotes,
    DateTime? createdAt,
  }) {
    return CommentReport(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      reviewedByModeratorId:
          reviewedByModeratorId ?? this.reviewedByModeratorId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      moderatorNotes: moderatorNotes ?? this.moderatorNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommentReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentReport(id: $id, commentId: $commentId, reason: ${reason.displayName}, status: ${status.displayName})';
  }
}
