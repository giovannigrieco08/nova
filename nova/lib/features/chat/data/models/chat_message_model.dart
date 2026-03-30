import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/mention_info.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/data/models/chat_media_model.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';

/// Data model for ChatMessage with JSON serialization.
///
/// Maps Supabase response to domain entity.
class ChatMessageModel {
  final String id;
  final String userId;
  final String? replyToId;
  final String content;
  final List<Map<String, dynamic>> mentionsJson;
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

  // Joined data from profiles
  final Map<String, dynamic>? authorJson;

  // Reply-to message data (single level)
  final Map<String, dynamic>? replyToJson;

  // Aggregated reactions
  final List<Map<String, dynamic>>? reactionsJson;

  // Media metadata
  final Map<String, dynamic>? mediaJson;

  const ChatMessageModel({
    required this.id,
    required this.userId,
    this.replyToId,
    required this.content,
    required this.mentionsJson,
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
    this.authorJson,
    this.replyToJson,
    this.reactionsJson,
    this.mediaJson,
  });

  /// Create from Supabase JSON response
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      replyToId: json['reply_to_id'] as String?,
      content: json['content'] as String,
      mentionsJson: _parseMentionsJson(json['mentions']),
      reactionCount: json['reaction_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      reportCount: json['report_count'] as int? ?? 0,
      hiddenAt: json['hidden_at'] != null
          ? DateTime.parse(json['hidden_at'] as String)
          : null,
      hiddenReason: json['hidden_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      originalContent: json['original_content'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      pinnedAt: json['pinned_at'] != null
          ? DateTime.parse(json['pinned_at'] as String)
          : null,
      pinnedByUserId: json['pinned_by_user_id'] as String?,
      gifUrl: json['gif_url'] as String?,
      gifId: json['gif_id'] as String?,
      mediaCaption: json['media_caption'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      deletedByUser: json['deleted_by_user'] as bool? ?? false,
      authorJson: json['profiles'] as Map<String, dynamic>?,
      replyToJson: json['reply_to'] as Map<String, dynamic>?,
      reactionsJson: _parseReactionsJson(json['chat_reactions']),
      mediaJson: _parseMediaJson(json['chat_media']),
    );
  }

  /// Convert to JSON for insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reply_to_id': replyToId,
      'content': content,
      'mentions': mentionsJson,
      'created_at': createdAt.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (deletedByUser) 'deleted_by_user': deletedByUser,
    };
  }

  /// Create insert payload (without server-generated fields)
  static Map<String, dynamic> toInsertJson({
    required String userId,
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  }) {
    return {
      'user_id': userId,
      'content': content,
      'mentions': mentions,
      'reply_to_id': replyToId,
    };
  }

  /// Convert to domain entity
  ChatMessage toEntity({
    required String currentUserId,
    Profile? author,
    ChatMessage? replyTo,
  }) {
    // Parse mentions
    final mentions = mentionsJson.map((m) => MentionInfo.fromJson(m)).toList();

    // Parse author from joined data
    final resolvedAuthor = author ?? _parseAuthor();

    // Parse reply-to message
    final resolvedReplyTo = replyTo ?? _parseReplyTo(currentUserId);

    // Aggregate reactions
    final reactionCounts = _aggregateReactionCounts();
    final currentUserReactions = _getCurrentUserReactions(currentUserId);

    // Parse media
    final media = _parseMedia();

    return ChatMessage(
      id: id,
      userId: userId,
      replyToId: replyToId,
      content: content,
      mentions: mentions,
      reactionCount: reactionCount,
      replyCount: replyCount,
      reportCount: reportCount,
      hiddenAt: hiddenAt,
      hiddenReason: hiddenReason,
      createdAt: createdAt,
      editedAt: editedAt,
      originalContent: originalContent,
      isPinned: isPinned,
      pinnedAt: pinnedAt,
      pinnedByUserId: pinnedByUserId,
      gifUrl: gifUrl,
      gifId: gifId,
      mediaCaption: mediaCaption,
      deletedAt: deletedAt,
      deletedByUser: deletedByUser,
      author: resolvedAuthor,
      replyTo: resolvedReplyTo,
      reactionCounts: reactionCounts,
      currentUserReactions: currentUserReactions,
      media: media,
    );
  }

  Profile _parseAuthor() {
    if (authorJson == null) {
      return _placeholderProfile(userId);
    }
    try {
      // Use ProfileModel to handle snake_case -> camelCase conversion
      return ProfileModel.fromJson(authorJson!).toEntity();
    } catch (e) {
      // If parsing fails (e.g., null required fields), return placeholder
      return _placeholderProfile(userId);
    }
  }

  static Profile _placeholderProfile(String id) {
    return Profile(
      userId: id,
      email: '',
      fullName: 'Utente',
      username: 'utente',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ChatMessage? _parseReplyTo(String currentUserId) {
    if (replyToJson == null) return null;

    try {
      final replyModel = ChatMessageModel.fromJson(replyToJson!);
      return replyModel.toEntity(
        currentUserId: currentUserId,
        replyTo: null, // Replies don't have nested replies
      );
    } catch (e) {
      // If parsing fails, return null (no reply-to displayed)
      return null;
    }
  }

  Map<String, int> _aggregateReactionCounts() {
    if (reactionsJson == null || reactionsJson!.isEmpty) {
      return {};
    }

    final counts = <String, int>{};
    for (final reaction in reactionsJson!) {
      final emoji = reaction['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  Set<String> _getCurrentUserReactions(String currentUserId) {
    if (reactionsJson == null || reactionsJson!.isEmpty) {
      return {};
    }

    return reactionsJson!
        .where((r) => r['user_id'] == currentUserId)
        .map((r) => r['emoji'] as String)
        .toSet();
  }

  ChatMediaInfo? _parseMedia() {
    if (mediaJson == null) return null;
    return ChatMediaModel.fromJson(mediaJson!).toEntity();
  }

  static List<Map<String, dynamic>> _parseMentionsJson(dynamic mentions) {
    if (mentions == null) return [];
    if (mentions is List) {
      return mentions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static List<Map<String, dynamic>>? _parseReactionsJson(dynamic reactions) {
    if (reactions == null) return null;
    if (reactions is List) {
      if (reactions.isEmpty) return [];
      return reactions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  static Map<String, dynamic>? _parseMediaJson(dynamic media) {
    if (media == null) {
      return null;
    }
    // chat_media can be a list (from join) or single object
    if (media is List) {
      if (media.isEmpty) {
        return null;
      }
      final result = Map<String, dynamic>.from(media.first as Map);
      return result;
    }
    if (media is Map) {
      final result = Map<String, dynamic>.from(media);
      return result;
    }
    return null;
  }
}
