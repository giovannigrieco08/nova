import 'package:nova/features/chat/domain/entities/mention_info.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';

/// Domain entity representing a message in the global chat.
///
/// Messages are ephemeral (24-hour auto-delete) and support:
/// - @mentions with notifications
/// - Emoji reactions (6 types)
/// - Single-level reply threading
/// - View-once media attachments
class ChatMessage {
  final String id;
  final String userId;
  final String? replyToId;
  final String content;
  final List<MentionInfo> mentions;
  final int reactionCount;
  final int replyCount;
  final int reportCount;
  final DateTime? hiddenAt;
  final String? hiddenReason;
  final DateTime createdAt;

  // Joined data (populated from related tables/profiles)
  final Profile author;
  final ChatMessage? replyTo;
  final Map<String, int> reactionCounts;
  final Set<String> currentUserReactions;
  final ChatMediaInfo? media;

  const ChatMessage({
    required this.id,
    required this.userId,
    this.replyToId,
    required this.content,
    required this.mentions,
    required this.reactionCount,
    required this.replyCount,
    required this.reportCount,
    this.hiddenAt,
    this.hiddenReason,
    required this.createdAt,
    required this.author,  // Profile entity
    this.replyTo,
    required this.reactionCounts,
    required this.currentUserReactions,
    this.media,
  });

  /// Whether the message is hidden by moderation
  bool get isHidden => hiddenAt != null;

  /// Whether this is a reply to another message
  bool get isReply => replyToId != null;

  /// Whether this message has attached media
  bool get hasMedia => media != null;

  /// Whether this message contains @mentions
  bool get hasMentions => mentions.isNotEmpty;

  /// Display text - returns placeholder if hidden
  String get displayContent {
    if (isHidden) return '[Messaggio nascosto]';
    return content;
  }

  /// Relative timestamp in Italian (e.g., "2 min fa", "1 ora fa")
  String get relativeTimestamp {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inSeconds < 60) return 'Adesso';
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min fa';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 ora fa' : '$hours ore fa';
    }
    return 'Ieri';
  }

  ChatMessage copyWith({
    String? id,
    String? userId,
    String? replyToId,
    String? content,
    List<MentionInfo>? mentions,
    int? reactionCount,
    int? replyCount,
    int? reportCount,
    DateTime? hiddenAt,
    String? hiddenReason,
    DateTime? createdAt,
    Profile? author,
    ChatMessage? replyTo,
    Map<String, int>? reactionCounts,
    Set<String>? currentUserReactions,
    ChatMediaInfo? media,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      replyToId: replyToId ?? this.replyToId,
      content: content ?? this.content,
      mentions: mentions ?? this.mentions,
      reactionCount: reactionCount ?? this.reactionCount,
      replyCount: replyCount ?? this.replyCount,
      reportCount: reportCount ?? this.reportCount,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      hiddenReason: hiddenReason ?? this.hiddenReason,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      replyTo: replyTo ?? this.replyTo,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      currentUserReactions: currentUserReactions ?? this.currentUserReactions,
      media: media ?? this.media,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
