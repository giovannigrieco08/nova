import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';

/// Implementation of [ChatRepository] using Supabase and Hive.
///
/// Handles:
/// - Remote operations via [ChatRemoteDataSource]
/// - Offline message queuing via Hive
/// - Error translation (Postgres errors → domain exceptions)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final SupabaseClient _supabase;
  final Box<Map<dynamic, dynamic>> _pendingMessagesBox;
  final Uuid _uuid;

  ChatRepositoryImpl({
    required ChatRemoteDataSource remoteDataSource,
    required SupabaseClient supabase,
    required Box<Map<dynamic, dynamic>> pendingMessagesBox,
  })  : _remoteDataSource = remoteDataSource,
        _supabase = supabase,
        _pendingMessagesBox = pendingMessagesBox,
        _uuid = const Uuid();

  String get _currentUserId => _supabase.auth.currentUser!.id;

  // =========================================================================
  // Messages
  // =========================================================================

  @override
  Stream<List<ChatMessage>> watchMessages({int limit = 50}) {
    return _remoteDataSource.watchMessages(limit: limit).map((models) {
      return models
          .map((m) => m.toEntity(currentUserId: _currentUserId))
          .toList();
    });
  }

  @override
  Future<List<ChatMessage>> loadMoreMessages({
    required DateTime beforeTimestamp,
    int limit = 20,
  }) async {
    final models = await _remoteDataSource.getMessages(
      limit: limit,
      beforeTimestamp: beforeTimestamp,
    );
    return models
        .map((m) => m.toEntity(currentUserId: _currentUserId))
        .toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  }) async {
    try {
      final model = await _remoteDataSource.sendMessage(
        userId: _currentUserId,
        content: content,
        mentions: mentions,
        replyToId: replyToId,
      );
      return model.toEntity(currentUserId: _currentUserId);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        throw const ChatRateLimitException(
            'Troppi messaggi. Attendi qualche secondo.');
      }
      if (e.code == 'P0002') {
        throw const ChatProfanityException(
            'Il messaggio contiene linguaggio inappropriato.');
      }
      rethrow;
    }
  }

  @override
  Future<ChatMessage?> getMessage(String messageId) async {
    final model = await _remoteDataSource.getMessage(messageId);
    return model?.toEntity(currentUserId: _currentUserId);
  }

  // =========================================================================
  // Reactions
  // =========================================================================

  @override
  Future<void> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    await _remoteDataSource.addReaction(
      messageId: messageId,
      userId: _currentUserId,
      emoji: emoji,
    );
  }

  @override
  Future<void> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    await _remoteDataSource.removeReaction(
      messageId: messageId,
      userId: _currentUserId,
      emoji: emoji,
    );
  }

  @override
  Future<Map<String, List<String>>> getReactionsForMessage(
      String messageId) async {
    final reactions =
        await _remoteDataSource.getReactionsForMessage(messageId);

    final result = <String, List<String>>{};
    for (final reaction in reactions) {
      final emoji = reaction.emoji;
      result.putIfAbsent(emoji, () => []);
      result[emoji]!.add(reaction.userId);
    }
    return result;
  }

  @override
  Stream<Map<String, List<ChatReaction>>> watchReactionsForMessage(
      String messageId) {
    // For real-time reactions, use broadcast channel
    // This is implemented in chat_realtime_provider.dart
    throw UnimplementedError(
        'Use ChatRealtimeProvider for real-time reactions');
  }

  // =========================================================================
  // Reports
  // =========================================================================

  @override
  Future<bool> submitReport({
    required String messageId,
    required ChatReportReason reason,
  }) async {
    final report = await _remoteDataSource.submitReport(
      messageId: messageId,
      reporterUserId: _currentUserId,
      reason: reason,
    );
    return report != null;
  }

  @override
  Future<bool> hasUserReported(String messageId) async {
    return _remoteDataSource.hasUserReported(
      messageId: messageId,
      userId: _currentUserId,
    );
  }

  // =========================================================================
  // @Mentions
  // =========================================================================

  @override
  Future<List<MentionSearchResult>> searchUsersForMention(String query) async {
    if (query.isEmpty) return [];
    return _remoteDataSource.searchUsersForMention(query);
  }

  // =========================================================================
  // Media (P3)
  // =========================================================================

  @override
  Future<ChatMediaInfo> uploadMedia({
    required String filePath,
    required ChatMediaType mediaType,
    int maxViews = 1,
  }) async {
    // Check daily limit
    final todayCount = await _remoteDataSource.getTodayMediaCount(_currentUserId);
    if (todayCount >= 5) {
      throw const ChatMediaLimitException(
          'Hai raggiunto il limite giornaliero di 5 media.');
    }

    // Create a message for the media (content will be hidden when media is attached)
    // Use a single space as placeholder - will be replaced by ChatMediaBubble
    final message = await sendMessage(content: ' ');

    // Upload media
    final model = await _remoteDataSource.uploadMedia(
      messageId: message.id,
      userId: _currentUserId,
      filePath: filePath,
      mediaType: mediaType,
      maxViews: maxViews,
    );

    return model.toEntity();
  }

  @override
  Future<String?> getSignedMediaUrl(String mediaId) async {
    // Get media record to check if it can still be viewed
    final response = await _supabase
        .from('chat_media')
        .select('storage_path, max_views, view_count')
        .eq('id', mediaId)
        .maybeSingle();

    if (response == null) return null;

    // Check if max views exceeded
    final maxViews = response['max_views'] as int? ?? 1;
    final viewCount = response['view_count'] as int? ?? 0;
    if (viewCount >= maxViews) return null;

    return _remoteDataSource.getSignedMediaUrl(response['storage_path']);
  }

  @override
  Future<ChatMediaInfo?> markMediaViewed(String mediaId) async {
    final model = await _remoteDataSource.markMediaViewed(
      mediaId: mediaId,
      viewerUserId: _currentUserId,
    );
    return model?.toEntity();
  }

  @override
  Future<void> reportScreenshot(String mediaId) async {
    await _remoteDataSource.reportScreenshot(mediaId);
  }

  @override
  Future<int> getTodayMediaCount() async {
    return _remoteDataSource.getTodayMediaCount(_currentUserId);
  }

  // =========================================================================
  // Offline Support
  // =========================================================================

  @override
  Future<void> queueOfflineMessage({
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  }) async {
    final localId = _uuid.v4();
    final pending = {
      'local_id': localId,
      'content': content,
      'mentions': mentions,
      'reply_to_id': replyToId,
      'queued_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    };
    await _pendingMessagesBox.put(localId, pending);
  }

  @override
  Future<List<PendingMessage>> getPendingMessages() async {
    return _pendingMessagesBox.values.map((data) {
      final map = Map<String, dynamic>.from(data);
      return PendingMessage(
        localId: map['local_id'] as String,
        content: map['content'] as String,
        mentions: (map['mentions'] as List).cast<Map<String, dynamic>>(),
        replyToId: map['reply_to_id'] as String?,
        queuedAt: DateTime.parse(map['queued_at'] as String),
        retryCount: map['retry_count'] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> clearPendingMessage(String localId) async {
    await _pendingMessagesBox.delete(localId);
  }
}
