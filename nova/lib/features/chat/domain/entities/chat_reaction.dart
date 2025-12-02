/// Domain entity representing an emoji reaction to a chat message.
///
/// Each user can add one reaction of each type per message.
/// Limited to 6 predefined emoji types.
class ChatReaction {
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const ChatReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatReaction &&
        other.messageId == messageId &&
        other.userId == userId &&
        other.emoji == emoji;
  }

  @override
  int get hashCode => Object.hash(messageId, userId, emoji);
}

/// Allowed emoji reactions for chat messages.
///
/// Whitelist enforced at database level.
class ChatEmoji {
  static const heart = '❤️';
  static const thumbsUp = '👍';
  static const laughing = '😂';
  static const surprised = '😮';
  static const sad = '😢';
  static const fire = '🔥';

  /// All available reaction emoji
  static const all = [heart, thumbsUp, laughing, surprised, sad, fire];

  /// Check if an emoji is in the allowed list
  static bool isValid(String emoji) => all.contains(emoji);

  /// Emoji labels for accessibility
  static String labelFor(String emoji) {
    switch (emoji) {
      case heart:
        return 'Cuore';
      case thumbsUp:
        return 'Mi piace';
      case laughing:
        return 'Divertente';
      case surprised:
        return 'Sorpreso';
      case sad:
        return 'Triste';
      case fire:
        return 'Fuoco';
      default:
        return emoji;
    }
  }

  const ChatEmoji._();
}
