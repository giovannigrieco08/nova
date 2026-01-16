import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';
import 'package:nova/features/chat/domain/entities/chat_report.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';

// Re-exports for convenience
export 'package:nova/features/chat/domain/entities/chat_report.dart'
    show ChatReportReason;
export 'package:nova/features/chat/domain/entities/chat_media_info.dart'
    show ChatMediaType;

/// Abstract repository interface for Global Chat operations.
///
/// Defines the contract for chat data access.
/// Implemented by [ChatRepositoryImpl] using Supabase.
abstract class ChatRepository {
  // =========================================================================
  // Messages
  // =========================================================================

  /// Stream of chat messages, ordered by creation time (newest first).
  ///
  /// Subscribes to real-time updates via Supabase Realtime.
  /// Hidden messages are filtered out for regular users.
  Stream<List<ChatMessage>> watchMessages({int limit = 50});

  /// Load older messages for pagination.
  ///
  /// Returns messages created before [beforeTimestamp].
  Future<List<ChatMessage>> loadMoreMessages({
    required DateTime beforeTimestamp,
    int limit = 20,
  });

  /// Send a new message to the global chat.
  ///
  /// Supports:
  /// - Text content (max 500 characters)
  /// - @mentions with notification
  /// - Reply threading (single level)
  ///
  /// Throws [ChatRateLimitException] if rate limit exceeded.
  /// Throws [ChatProfanityException] if content contains profanity.
  Future<ChatMessage> sendMessage({
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  });

  /// Get a single message by ID.
  ///
  /// Returns null if message not found or hidden.
  Future<ChatMessage?> getMessage(String messageId);

  /// Delete a message (only allowed within 30 minutes of sending).
  ///
  /// Returns true if message was deleted, false if not allowed.
  /// Throws [ChatDeleteNotAllowedException] if deletion window has passed.
  Future<bool> deleteMessage(String messageId);

  // =========================================================================
  // Reactions
  // =========================================================================

  /// Add a reaction to a message.
  ///
  /// No-op if the user already has this reaction on the message.
  Future<void> addReaction({
    required String messageId,
    required String emoji,
  });

  /// Remove a reaction from a message.
  Future<void> removeReaction({
    required String messageId,
    required String emoji,
  });

  /// Get all reactions for a message.
  ///
  /// Returns a map of emoji -> list of user IDs who reacted.
  Future<Map<String, List<String>>> getReactionsForMessage(String messageId);

  /// Stream reactions for a message in real-time.
  Stream<Map<String, List<ChatReaction>>> watchReactionsForMessage(
      String messageId);

  // =========================================================================
  // Reports
  // =========================================================================

  /// Submit a report for an inappropriate message.
  ///
  /// Returns true if report was created, false if already reported.
  Future<bool> submitReport({
    required String messageId,
    required ChatReportReason reason,
  });

  /// Check if current user has already reported a message.
  Future<bool> hasUserReported(String messageId);

  // =========================================================================
  // @Mentions
  // =========================================================================

  /// Search users for @mention autocomplete.
  ///
  /// Uses trigram matching for fuzzy search.
  /// Returns max 5 results.
  Future<List<MentionSearchResult>> searchUsersForMention(String query);

  // =========================================================================
  // Media (P3)
  // =========================================================================

  /// Upload ephemeral media and attach to a message.
  ///
  /// [maxViews] determines how many times the media can be viewed (1 or 2).
  /// [durationSeconds] is the duration for audio messages.
  /// [caption] is an optional caption for images/videos.
  /// Returns the media info on success.
  /// Throws [ChatMediaLimitException] if daily limit exceeded (5/day).
  Future<ChatMediaInfo> uploadMedia({
    required String filePath,
    required ChatMediaType mediaType,
    int maxViews = 1,
    int? durationSeconds,
    String? caption,
  });

  /// Get a signed URL for viewing media (expires in 60 seconds).
  ///
  /// Returns null if media has used all views or expired.
  Future<String?> getSignedMediaUrl(String mediaId);

  /// Mark media as viewed (increments view count).
  ///
  /// Returns updated media info, or null if max views exceeded.
  Future<ChatMediaInfo?> markMediaViewed(String mediaId);

  /// Report a screenshot was detected on iOS.
  Future<void> reportScreenshot(String mediaId);

  /// Check today's media upload count for the current user.
  Future<int> getTodayMediaCount();

  // =========================================================================
  // GIF Messages
  // =========================================================================

  /// Send a GIF message.
  ///
  /// [gifUrl] is the URL of the GIF to display.
  /// [gifId] is the GIPHY/Tenor ID for tracking.
  Future<ChatMessage> sendGifMessage({
    required String gifUrl,
    required String gifId,
    String? replyToId,
  });

  // =========================================================================
  // Edit Messages
  // =========================================================================

  /// Edit a message (within 5-minute window).
  ///
  /// Returns updated message on success.
  /// Throws [ChatEditNotAllowedException] if edit window expired.
  Future<ChatMessage> editMessage({
    required String messageId,
    required String newContent,
  });

  // =========================================================================
  // Pin Messages
  // =========================================================================

  /// Pin a message to the chat.
  ///
  /// Only one message can be pinned at a time.
  /// Pinning a new message unpins the previous one.
  Future<ChatMessage> pinMessage(String messageId);

  /// Unpin the currently pinned message.
  Future<void> unpinMessage(String messageId);

  /// Get the currently pinned message, if any.
  Future<ChatMessage?> getPinnedMessage();

  // =========================================================================
  // Offline Support
  // =========================================================================

  /// Queue a message for sending when offline.
  ///
  /// Messages are automatically retried when connection is restored.
  Future<void> queueOfflineMessage({
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  });

  /// Get pending offline messages.
  Future<List<PendingMessage>> getPendingMessages();

  /// Clear a pending message after successful send.
  Future<void> clearPendingMessage(String localId);
}

/// Result from @mention user search
class MentionSearchResult {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? studentClass;

  const MentionSearchResult({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.studentClass,
  });
}

/// A message pending offline sync
class PendingMessage {
  final String localId;
  final String content;
  final List<Map<String, dynamic>> mentions;
  final String? replyToId;
  final DateTime queuedAt;
  final int retryCount;

  const PendingMessage({
    required this.localId,
    required this.content,
    required this.mentions,
    this.replyToId,
    required this.queuedAt,
    this.retryCount = 0,
  });
}

/// Exception thrown when chat rate limit is exceeded
class ChatRateLimitException implements Exception {
  final String message;
  const ChatRateLimitException([this.message = 'Rate limit exceeded']);

  @override
  String toString() => 'ChatRateLimitException: $message';
}

/// Exception thrown when message contains profanity
class ChatProfanityException implements Exception {
  final String message;
  const ChatProfanityException(
      [this.message = 'Message contains inappropriate language']);

  @override
  String toString() => 'ChatProfanityException: $message';
}

/// Exception thrown when media upload limit is exceeded
class ChatMediaLimitException implements Exception {
  final String message;
  const ChatMediaLimitException(
      [this.message = 'Daily media upload limit exceeded']);

  @override
  String toString() => 'ChatMediaLimitException: $message';
}

/// Exception thrown when message deletion is not allowed
class ChatDeleteNotAllowedException implements Exception {
  final String message;
  const ChatDeleteNotAllowedException(
      [this.message = 'Message deletion not allowed after 30 minutes']);

  @override
  String toString() => 'ChatDeleteNotAllowedException: $message';
}

/// Exception thrown when message edit is not allowed
class ChatEditNotAllowedException implements Exception {
  final String message;
  const ChatEditNotAllowedException(
      [this.message = 'Message edit not allowed after 5 minutes']);

  @override
  String toString() => 'ChatEditNotAllowedException: $message';
}
