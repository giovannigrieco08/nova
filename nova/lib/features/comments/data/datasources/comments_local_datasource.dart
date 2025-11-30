import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/comment.dart';
import '../../domain/entities/comment_report.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import '../models/comment_model.dart';

/// CommentsLocalDataSource
///
/// Handles local Hive cache for offline comment viewing and action queuing.
/// Implements 15-minute TTL for cached comments and FIFO queue for offline actions.
///
/// Constitutional Principle 5 (SPEC_FIRST): Data layer provides offline-first
/// support using Hive for local persistence during network unavailability.
///
/// Cache Strategy:
/// - Comments cached per event_id with timestamp
/// - 15-minute TTL enforced on read
/// - Offline actions queued with client-generated UUID
/// - Queue synced on network restoration (FIFO order)
class CommentsLocalDataSource {
  static const String _commentsCacheBoxName = 'comments_cache';
  static const String _offlineQueueBoxName = 'comments_offline_queue';
  static const Duration _cacheTTL = Duration(minutes: 15);

  late Box<Map<dynamic, dynamic>> _commentsCache;
  late Box<Map<dynamic, dynamic>> _offlineQueue;

  /// Initialize Hive boxes
  ///
  /// Must be called before any other operations.
  /// Typically called during app initialization in main.dart.
  Future<void> init() async {
    await Hive.initFlutter();

    // Register Hive adapters if needed (for custom types)
    // Note: Using JSON serialization (Map<String, dynamic>) to avoid custom adapters

    _commentsCache = await Hive.openBox<Map<dynamic, dynamic>>(
      _commentsCacheBoxName,
    );
    _offlineQueue = await Hive.openBox<Map<dynamic, dynamic>>(
      _offlineQueueBoxName,
    );
  }

  // ==========================================================================
  // CACHE OPERATIONS
  // ==========================================================================

  /// Get cached comments for an event
  ///
  /// Returns null if cache miss, expired (>15 min), or Hive error.
  /// Automatically purges expired entries on read.
  Future<List<CommentModel>?> getCachedComments({
    required String eventId,
  }) async {
    try {
      final cacheKey = 'event_$eventId';
      final cachedData = _commentsCache.get(cacheKey);

      if (cachedData == null) {
        return null; // Cache miss
      }

      // Parse cache entry
      final timestampStr = cachedData['timestamp'] as String?;
      final commentsJson = cachedData['comments'] as List<dynamic>?;

      if (timestampStr == null || commentsJson == null) {
        // Corrupted cache entry - delete it
        await _commentsCache.delete(cacheKey);
        return null;
      }

      // Check TTL (15 minutes)
      final timestamp = DateTime.parse(timestampStr);
      final age = DateTime.now().difference(timestamp);

      if (age > _cacheTTL) {
        // Cache expired - delete and return null
        await _commentsCache.delete(cacheKey);
        return null;
      }

      // Parse comments from JSON
      final comments = commentsJson
          .cast<Map<String, dynamic>>()
          .map((json) => CommentModel.fromJson(json))
          .toList();

      return comments;
    } catch (e) {
      // Hive error or JSON parsing error - return null (fail silently)
      // Log error in production for debugging
      print('Error reading cache for event $eventId: $e');
      return null;
    }
  }

  /// Cache comments for an event
  ///
  /// Stores comments with current timestamp for TTL enforcement.
  /// Overwrites existing cache for the same event_id.
  Future<void> cacheComments({
    required String eventId,
    required List<Comment> comments,
  }) async {
    try {
      final cacheKey = 'event_$eventId';

      // Convert entities to models for JSON serialization
      final commentsJson = comments
          .map((c) => CommentModel.fromEntity(c).toJson())
          .toList();

      // Create cache entry with timestamp
      final cacheEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'comments': commentsJson,
      };

      // Store in Hive
      await _commentsCache.put(cacheKey, cacheEntry);
    } catch (e) {
      // Hive error (disk full, permissions, etc.)
      // Log but don't throw - caching is best-effort
      print('Error caching comments for event $eventId: $e');
    }
  }

  /// Clear all cached comments
  ///
  /// Used when user logs out or for cache management.
  Future<void> clearCache() async {
    try {
      await _commentsCache.clear();
    } catch (e) {
      print('Error clearing comments cache: $e');
    }
  }

  /// Clear expired cache entries
  ///
  /// Should be called periodically (e.g., on app startup) to prevent cache bloat.
  Future<void> cleanupExpiredCache() async {
    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final key in _commentsCache.keys) {
        final cachedData = _commentsCache.get(key);
        if (cachedData == null) continue;

        final timestampStr = cachedData['timestamp'] as String?;
        if (timestampStr == null) {
          keysToDelete.add(key as String);
          continue;
        }

        final timestamp = DateTime.parse(timestampStr);
        final age = now.difference(timestamp);

        if (age > _cacheTTL) {
          keysToDelete.add(key as String);
        }
      }

      // Delete expired entries
      for (final key in keysToDelete) {
        await _commentsCache.delete(key);
      }

      print('Cleaned up ${keysToDelete.length} expired cache entries');
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }

  // ==========================================================================
  // OFFLINE QUEUE OPERATIONS
  // ==========================================================================

  /// Queue an offline action for sync when online
  ///
  /// Actions are stored in FIFO order with client-generated UUID.
  /// Duplicates are allowed (idempotency handled server-side).
  Future<void> queueOfflineAction({
    required OfflineCommentAction action,
  }) async {
    try {
      // Serialize action to JSON
      final actionJson = {
        'temp_id': action.tempId,
        'type': action.type.name,
        'comment_id': action.commentId,
        'event_id': action.eventId,
        'parent_comment_id': action.parentCommentId,
        'text': action.text,
        'report_reason': action.reportReason?.value,
        'report_details': action.reportDetails,
        'queued_at': action.queuedAt.toIso8601String(),
      };

      // Add to queue (key = temp_id for easy lookup)
      await _offlineQueue.put(action.tempId, actionJson);

      print('Queued offline action: ${action.type.name} (${action.tempId})');
    } catch (e) {
      // Hive error - log but don't throw
      print('Error queuing offline action: $e');
    }
  }

  /// Get all queued offline actions
  ///
  /// Returns actions in FIFO order (oldest first).
  Future<List<OfflineCommentAction>> getOfflineQueue() async {
    try {
      final actions = <OfflineCommentAction>[];

      for (final actionJson in _offlineQueue.values) {
        final action = _parseOfflineAction(actionJson);
        if (action != null) {
          actions.add(action);
        }
      }

      // Sort by queued_at (FIFO)
      actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      return actions;
    } catch (e) {
      print('Error reading offline queue: $e');
      return [];
    }
  }

  /// Remove an action from the offline queue
  ///
  /// Called after successful sync or when action fails permanently.
  Future<void> removeFromQueue({
    required String tempId,
  }) async {
    try {
      await _offlineQueue.delete(tempId);
    } catch (e) {
      print('Error removing action from queue: $e');
    }
  }

  /// Clear entire offline queue
  ///
  /// Used after successful sync or on user request.
  Future<void> clearOfflineQueue() async {
    try {
      await _offlineQueue.clear();
      print('Offline queue cleared');
    } catch (e) {
      print('Error clearing offline queue: $e');
    }
  }

  /// Get offline queue size
  ///
  /// Useful for UI indicators ("X pending actions").
  int getQueueSize() {
    try {
      return _offlineQueue.length;
    } catch (e) {
      print('Error getting queue size: $e');
      return 0;
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Parse offline action from JSON
  ///
  /// Returns null if JSON is corrupted or invalid.
  OfflineCommentAction? _parseOfflineAction(Map<dynamic, dynamic> json) {
    try {
      final typeStr = json['type'] as String?;
      if (typeStr == null) return null;

      final type = OfflineActionType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => OfflineActionType.post,
      );

      final queuedAtStr = json['queued_at'] as String?;
      if (queuedAtStr == null) return null;

      return OfflineCommentAction(
        tempId: json['temp_id'] as String,
        type: type,
        commentId: json['comment_id'] as String?,
        eventId: json['event_id'] as String?,
        parentCommentId: json['parent_comment_id'] as String?,
        text: json['text'] as String?,
        reportReason: json['report_reason'] != null
            ? CommentReportReason.fromValue(json['report_reason'] as String)
            : null,
        reportDetails: json['report_details'] as String?,
        queuedAt: DateTime.parse(queuedAtStr),
      );
    } catch (e) {
      print('Error parsing offline action: $e');
      return null;
    }
  }

  // ==========================================================================
  // LIFECYCLE METHODS
  // ==========================================================================

  /// Close Hive boxes
  ///
  /// Should be called when app is shutting down.
  Future<void> dispose() async {
    try {
      await _commentsCache.close();
      await _offlineQueue.close();
    } catch (e) {
      print('Error closing Hive boxes: $e');
    }
  }
}
