/// Domain entity for reporting inappropriate chat messages.
///
/// Users can report messages for 4 reasons.
/// Auto-hide triggers at 3 unique reports.
class ChatReport {
  final String id;
  final String messageId;
  final String reporterUserId;
  final ChatReportReason reason;
  final ChatReportStatus status;
  final String? reviewedByModeratorId;
  final DateTime? reviewedAt;
  final String? moderatorNotes;
  final DateTime createdAt;

  const ChatReport({
    required this.id,
    required this.messageId,
    required this.reporterUserId,
    required this.reason,
    required this.status,
    this.reviewedByModeratorId,
    this.reviewedAt,
    this.moderatorNotes,
    required this.createdAt,
  });

  /// Whether this report has been reviewed
  bool get isReviewed => status != ChatReportStatus.pending;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Reasons for reporting a chat message
enum ChatReportReason {
  spam('spam', 'Spam'),
  inappropriate('inappropriate', 'Contenuto inappropriato'),
  bullying('bullying', 'Bullismo'),
  offTopic('off_topic', 'Off-topic');

  /// Database value
  final String value;

  /// Italian display label
  final String label;

  const ChatReportReason(this.value, this.label);

  static ChatReportReason fromValue(String value) {
    return values.firstWhere(
      (r) => r.value == value,
      orElse: () => ChatReportReason.inappropriate,
    );
  }
}

/// Status of a chat report in the moderation workflow
enum ChatReportStatus {
  pending('pending', 'In attesa'),
  reviewed('reviewed', 'Revisionato'),
  dismissed('dismissed', 'Respinto');

  /// Database value
  final String value;

  /// Italian display label
  final String label;

  const ChatReportStatus(this.value, this.label);

  static ChatReportStatus fromValue(String value) {
    return values.firstWhere(
      (s) => s.value == value,
      orElse: () => ChatReportStatus.pending,
    );
  }
}
