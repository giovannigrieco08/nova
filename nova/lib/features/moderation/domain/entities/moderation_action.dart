// =====================================================================
// ModerationAction Enum - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Define moderation actions for event review
// Architecture: Simple enum with string conversion
// =====================================================================

/// Moderation action taken on an event
///
/// Represents the decision made by a moderator when reviewing a pending event.
enum ModerationAction {
  /// Event approved - will be visible to all students
  approved,

  /// Event rejected - visible only to creator with rejection reason
  rejected;

  /// Convert to database string value
  @override
  String toString() {
    switch (this) {
      case ModerationAction.approved:
        return 'approved';
      case ModerationAction.rejected:
        return 'rejected';
    }
  }

  /// Convert from database string value
  static ModerationAction fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return ModerationAction.approved;
      case 'rejected':
        return ModerationAction.rejected;
      default:
        throw ArgumentError('Invalid moderation action: $value');
    }
  }

  /// Get user-friendly Italian label
  String get label {
    switch (this) {
      case ModerationAction.approved:
        return 'Approvato';
      case ModerationAction.rejected:
        return 'Rifiutato';
    }
  }
}
