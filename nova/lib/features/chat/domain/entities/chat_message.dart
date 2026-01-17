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
/// - Edit (within 15 minutes)
/// - Delete (soft delete, shows "Messaggio eliminato" placeholder)
/// - Pin messages
/// - GIF support
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

  // Edit support
  final DateTime? editedAt;
  final String? originalContent;

  // Pin support
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedByUserId;

  // GIF support
  final String? gifUrl;
  final String? gifId;

  // Media caption
  final String? mediaCaption;

  // Soft delete support
  final DateTime? deletedAt;
  final bool deletedByUser;

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
    this.editedAt,
    this.originalContent,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedByUserId,
    this.gifUrl,
    this.gifId,
    this.mediaCaption,
    this.deletedAt,
    this.deletedByUser = false,
    required this.author,
    this.replyTo,
    required this.reactionCounts,
    required this.currentUserReactions,
    this.media,
  });

  /// Whether the message is hidden by moderation
  bool get isHidden => hiddenAt != null;

  /// Whether the message has been soft-deleted by the user
  bool get isDeleted => deletedAt != null;

  /// Whether this is a reply to another message
  bool get isReply => replyToId != null;

  /// Whether this message has attached media
  bool get hasMedia => media != null;

  /// Whether this message contains @mentions
  bool get hasMentions => mentions.isNotEmpty;

  /// Whether the message can be deleted (always true unless already deleted)
  bool get canDelete => !isDeleted;

  /// Whether the message has been edited
  bool get isEdited => editedAt != null;

  /// Edit window in minutes (15 minutes per spec)
  static const int editWindowMinutes = 15;

  /// Whether the message can be edited (within 15 minutes, not deleted)
  bool get canEdit {
    if (isDeleted) return false;
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes < editWindowMinutes;
  }

  /// Minutes remaining until message can no longer be edited
  int get editWindowMinutesRemaining {
    if (!canEdit) return 0;
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final remaining = editWindowMinutes - difference.inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether this is a GIF message
  bool get isGif => gifUrl != null && gifUrl!.isNotEmpty;

  /// Whether this message has a media caption
  bool get hasCaption => mediaCaption != null && mediaCaption!.isNotEmpty;

  /// Display text - returns placeholder if hidden or deleted
  String get displayContent {
    if (isDeleted) return 'Messaggio eliminato';
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
    DateTime? editedAt,
    String? originalContent,
    bool? isPinned,
    DateTime? pinnedAt,
    String? pinnedByUserId,
    String? gifUrl,
    String? gifId,
    String? mediaCaption,
    DateTime? deletedAt,
    bool? deletedByUser,
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
      editedAt: editedAt ?? this.editedAt,
      originalContent: originalContent ?? this.originalContent,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedByUserId: pinnedByUserId ?? this.pinnedByUserId,
      gifUrl: gifUrl ?? this.gifUrl,
      gifId: gifId ?? this.gifId,
      mediaCaption: mediaCaption ?? this.mediaCaption,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedByUser: deletedByUser ?? this.deletedByUser,
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
