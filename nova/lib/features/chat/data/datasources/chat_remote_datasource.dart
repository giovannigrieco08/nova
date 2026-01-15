import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/chat/data/models/chat_message_model.dart';
import 'package:nova/features/chat/data/models/chat_reaction_model.dart';
import 'package:nova/features/chat/data/models/chat_report_model.dart';
import 'package:nova/features/chat/data/models/chat_media_model.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';

/// Remote data source for Global Chat using Supabase.
///
/// Handles all network operations including:
/// - Real-time message streaming
/// - CRUD operations for messages, reactions, reports
/// - Media upload/download with signed URLs
/// - @mention user search
class ChatRemoteDataSource {
  final SupabaseClient _supabase;

  ChatRemoteDataSource(this._supabase);

  // =========================================================================
  // Messages
  // =========================================================================

  /// Stream of chat messages with real-time updates.
  ///
  /// Returns messages ordered by creation time (newest first).
  /// Joins with profiles for author info.
  Stream<List<ChatMessageModel>> watchMessages({int limit = 50}) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((json) => ChatMessageModel.fromJson(json)).toList());
  }

  /// Get messages with full joins (for initial load).
  Future<List<ChatMessageModel>> getMessages({
    int limit = 50,
    DateTime? beforeTimestamp,
  }) async {
    // Build the query with filters first, then transformations
    var queryBuilder = _supabase
        .from('chat_messages')
        .select('''
          *,
          profiles:user_id(user_id, email, full_name, username, avatar_url, class, role, profile_visible, bio, created_at, updated_at, deleted_at),
          reply_to:reply_to_id(
            id, user_id, content, created_at,
            profiles:user_id(user_id, email, full_name, username, avatar_url, class, role, profile_visible, bio, created_at, updated_at, deleted_at)
          ),
          chat_reactions(message_id, user_id, emoji),
          chat_media(*)
        ''');

    // Apply filter if timestamp provided
    if (beforeTimestamp != null) {
      queryBuilder = queryBuilder.lt('created_at', beforeTimestamp.toIso8601String());
    }

    // Apply ordering and limit
    List<dynamic> responseList;
    try {
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .limit(limit);
      responseList = response;

    } catch (e) {
      throw Exception(
        'Database error: le tabelle della chat potrebbero non esistere. '
        'Esegui le migrazioni SQL su Supabase. Dettaglio: $e',
      );
    }

    return responseList
        .map((json) => ChatMessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single message by ID with full joins.
  Future<ChatMessageModel?> getMessage(String messageId) async {
    final response = await _supabase
        .from('chat_messages')
        .select('''
          *,
          profiles:user_id(user_id, email, full_name, username, avatar_url, class, role, profile_visible, bio, created_at, updated_at, deleted_at),
          reply_to:reply_to_id(
            id, user_id, content, created_at,
            profiles:user_id(user_id, email, full_name, username, avatar_url, class, role, profile_visible, bio, created_at, updated_at, deleted_at)
          ),
          chat_reactions(message_id, user_id, emoji),
          chat_media(*)
        ''')
        .eq('id', messageId)
        .maybeSingle();

    if (response == null) return null;
    return ChatMessageModel.fromJson(response);
  }

  /// Send a new message.
  ///
  /// Throws PostgrestException with code P0001 for rate limit.
  /// Throws PostgrestException with code P0002 for profanity.
  Future<ChatMessageModel> sendMessage({
    required String userId,
    required String content,
    List<Map<String, dynamic>> mentions = const [],
    String? replyToId,
  }) async {
    final response = await _supabase
        .from('chat_messages')
        .insert(ChatMessageModel.toInsertJson(
          userId: userId,
          content: content,
          mentions: mentions,
          replyToId: replyToId,
        ))
        .select('''
          *,
          profiles:user_id(user_id, email, full_name, username, avatar_url, class, role, profile_visible, bio, created_at, updated_at, deleted_at)
        ''')
        .single();

    return ChatMessageModel.fromJson(response);
  }

  /// Delete a message.
  ///
  /// Also deletes associated reactions, reports, and media.
  Future<void> deleteMessage(String messageId) async {
    // Delete related media files from storage first
    final mediaResponse = await _supabase
        .from('chat_media')
        .select('storage_path')
        .eq('message_id', messageId);

    for (final media in (mediaResponse as List)) {
      final storagePath = media['storage_path'] as String?;
      if (storagePath != null) {
        try {
          await _supabase.storage.from('ephemeral-media').remove([storagePath]);
        } catch (e) {
          // Ignore errors deleting media files
        }
      }
    }

    // Delete message (cascade will handle reactions, reports, media records)
    await _supabase.from('chat_messages').delete().eq('id', messageId);
  }

  // =========================================================================
  // Reactions
  // =========================================================================

  /// Add a reaction to a message.
  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _supabase.from('chat_reactions').upsert(
      ChatReactionModel.toInsertJson(
        messageId: messageId,
        userId: userId,
        emoji: emoji,
      ),
      onConflict: 'message_id, user_id, emoji',
    );
  }

  /// Remove a reaction from a message.
  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _supabase
        .from('chat_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  /// Get all reactions for a message.
  Future<List<ChatReactionModel>> getReactionsForMessage(
      String messageId) async {
    final response = await _supabase
        .from('chat_reactions')
        .select()
        .eq('message_id', messageId)
        .order('created_at');

    return (response as List)
        .map((json) => ChatReactionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get all reactions for a message with user profile info.
  ///
  /// Returns list of (emoji, userId, fullName, avatarUrl) tuples.
  Future<List<ReactionWithUser>> getReactionsWithUsers(
      String messageId) async {
    final response = await _supabase
        .from('chat_reactions')
        .select('emoji, user_id, created_at, profiles:user_id(full_name, avatar_url)')
        .eq('message_id', messageId)
        .order('created_at');

    return (response as List).map((json) {
      final profiles = json['profiles'] as Map<String, dynamic>?;
      return ReactionWithUser(
        emoji: json['emoji'] as String,
        userId: json['user_id'] as String,
        fullName: profiles?['full_name'] as String? ?? 'Utente',
        avatarUrl: profiles?['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    }).toList();
  }

  // =========================================================================
  // Reports
  // =========================================================================

  /// Submit a report for a message.
  ///
  /// Returns the created report, or null if duplicate (already reported).
  Future<ChatReportModel?> submitReport({
    required String messageId,
    required String reporterUserId,
    required ChatReportReason reason,
  }) async {
    try {
      final response = await _supabase
          .from('chat_reports')
          .insert(ChatReportModel.toInsertJson(
            messageId: messageId,
            reporterUserId: reporterUserId,
            reason: reason,
          ))
          .select()
          .single();

      return ChatReportModel.fromJson(response);
    } on PostgrestException catch (e) {
      // Unique constraint violation = already reported
      if (e.code == '23505') {
        return null;
      }
      rethrow;
    }
  }

  /// Check if user has already reported a message.
  Future<bool> hasUserReported({
    required String messageId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('chat_reports')
        .select('id')
        .eq('message_id', messageId)
        .eq('reporter_user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // =========================================================================
  // @Mention Search
  // =========================================================================

  /// Search users for @mention autocomplete.
  Future<List<MentionSearchResult>> searchUsersForMention(String query) async {
    final response = await _supabase.rpc(
      'search_users_for_mention',
      params: {'search_term': query},
    );

    return (response as List).map((json) {
      return MentionSearchResult(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        studentClass: json['class'] as String?,
      );
    }).toList();
  }

  // =========================================================================
  // Media (P3)
  // =========================================================================

  /// Upload media to ephemeral-media bucket.
  ///
  /// [maxViews] determines how many times the media can be viewed (1 or 2).
  /// [durationSeconds] is the duration for audio messages.
  Future<ChatMediaModel> uploadMedia({
    required String messageId,
    required String userId,
    required String filePath,
    required ChatMediaType mediaType,
    int maxViews = 1,
    int? durationSeconds,
  }) async {
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.${_getExtension(mediaType)}';
    final storagePath = '$userId/$fileName';

    // Upload to storage
    await _supabase.storage
        .from('ephemeral-media')
        .uploadBinary(storagePath, fileBytes);

    // Create media record
    final response = await _supabase
        .from('chat_media')
        .insert(ChatMediaModel.toInsertJson(
          messageId: messageId,
          uploaderUserId: userId,
          storagePath: storagePath,
          mediaType: mediaType,
          fileSizeBytes: fileBytes.length,
          maxViews: maxViews,
          durationSeconds: durationSeconds,
        ))
        .select()
        .single();

    return ChatMediaModel.fromJson(response);
  }

  /// Get a signed URL for viewing media (60 second expiry).
  Future<String?> getSignedMediaUrl(String storagePath) async {
    try {
      final response = await _supabase.storage
          .from('ephemeral-media')
          .createSignedUrl(storagePath, 60);
      return response;
    } catch (e, stackTrace) {
      return null;
    }
  }

  /// Mark media as viewed (increments view_count).
  ///
  /// Returns the updated media record, or null if max views exceeded.
  Future<ChatMediaModel?> markMediaViewed({
    required String mediaId,
    required String viewerUserId,
  }) async {
    // Use RPC to atomically increment view_count and check max_views
    final response = await _supabase.rpc(
      'increment_media_view_count',
      params: {
        'p_media_id': mediaId,
        'p_viewer_user_id': viewerUserId,
      },
    );

    // RPC returns a TABLE (list of rows), so we need to get the first row
    if (response == null) return null;

    // Handle both List (from RETURNS TABLE) and Map (single row)
    final Map<String, dynamic> mediaJson;
    if (response is List) {
      if (response.isEmpty) return null;
      mediaJson = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      mediaJson = Map<String, dynamic>.from(response);
    } else {
      return null;
    }

    return ChatMediaModel.fromJson(mediaJson);
  }

  /// Report a screenshot was detected.
  Future<void> reportScreenshot(String mediaId) async {
    await _supabase.from('chat_media').update({
      'screenshot_detected_at': DateTime.now().toIso8601String(),
    }).eq('id', mediaId);
  }

  /// Get today's media upload count for user.
  Future<int> getTodayMediaCount(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final response = await _supabase
        .from('chat_media')
        .select('id')
        .eq('uploader_user_id', userId)
        .gte('created_at', startOfDay.toIso8601String());

    return (response as List).length;
  }

  String _getExtension(ChatMediaType type) {
    switch (type) {
      case ChatMediaType.image:
        return 'webp';
      case ChatMediaType.video:
        return 'mp4';
      case ChatMediaType.audio:
        return 'aac';
    }
  }
}

/// Reaction with user profile information.
///
/// Used for displaying who reacted to a message.
class ReactionWithUser {
  final String emoji;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final DateTime createdAt;

  const ReactionWithUser({
    required this.emoji,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.createdAt,
  });
}
