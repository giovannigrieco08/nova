// Domain Entity: Comment
// Feature: 003-events-feed
// Purpose: Business logic representation of an event comment

class Comment {
  final String id;
  final String eventId;
  final String authorId;
  final String content; // Max 500 characters (renamed from 'text' to match DB schema)
  final DateTime createdAt;

  // Optional author profile data (from joins)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorClass;

  Comment({
    required this.id,
    required this.eventId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
    this.authorClass,
  });

  /// Check if comment exceeds character limit (500)
  bool get exceedsLimit => content.length > 500;

  /// Get remaining characters (for character counter)
  int get remainingCharacters => 500 - content.length;

  /// Format timestamp for display (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Check if current user is the author (requires user ID)
  bool isAuthor(String userId) => authorId == userId;

  /// CopyWith for partial updates
  Comment copyWith({
    String? id,
    String? eventId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    String? authorName,
    String? authorAvatarUrl,
    String? authorClass,
  }) {
    return Comment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorClass: authorClass ?? this.authorClass,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Comment(id: $id, authorId: $authorId, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}...)';
  }
}
