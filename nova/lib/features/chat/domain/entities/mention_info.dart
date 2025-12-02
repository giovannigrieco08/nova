/// Information about an @mention within a chat message.
///
/// Stores the position of the mention in the content string
/// for proper highlighting and linking.
class MentionInfo {
  /// The user ID of the mentioned user
  final String userId;

  /// Display name at the time of mention (may change later)
  final String username;

  /// Start position in the content string
  final int startIndex;

  /// End position in the content string
  final int endIndex;

  const MentionInfo({
    required this.userId,
    required this.username,
    required this.startIndex,
    required this.endIndex,
  });

  /// Length of the mention text
  int get length => endIndex - startIndex;

  factory MentionInfo.fromJson(Map<String, dynamic> json) {
    return MentionInfo(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      startIndex: json['start_index'] as int,
      endIndex: json['end_index'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'start_index': startIndex,
        'end_index': endIndex,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MentionInfo &&
        other.userId == userId &&
        other.startIndex == startIndex;
  }

  @override
  int get hashCode => Object.hash(userId, startIndex);
}
