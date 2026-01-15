import 'package:hive_flutter/hive_flutter.dart';

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

  Box<Map<dynamic, dynamic>>? _commentsCache;
  Box<Map<dynamic, dynamic>>? _offlineQueue;
  bool _isInitializing = false;

  /// Initialize Hive boxes
  ///
  /// Can be called explicitly during app startup, but will also be
  /// called lazily on first access if not initialized.
  Future<void> init() async {
    if (_commentsCache != null && _offlineQueue != null) {
      return; // Already initialized
    }

    if (_isInitializing) {
      // Wait for ongoing initialization
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }

    _isInitializing = true;
    try {
      await Hive.initFlutter();

      // Register Hive adapters if needed (for custom types)
      // Note: Using JSON serialization (Map<String, dynamic>) to avoid custom adapters

      _commentsCache = await Hive.openBox<Map<dynamic, dynamic>>(
        _commentsCacheBoxName,
      );
      _offlineQueue = await Hive.openBox<Map<dynamic, dynamic>>(
        _offlineQueueBoxName,
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// Ensure boxes are initialized before accessing them
  Future<void> _ensureInitialized() async {
    if (_commentsCache == null || _offlineQueue == null) {
      await init();
    }
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
      await _ensureInitialized();
      final cacheKey = 'event_$eventId';
      final cachedData = _commentsCache?.get(cacheKey);

      if (cachedData == null) {
        return null; // Cache miss
      }

      // Parse cache entry
      final timestampStr = cachedData['timestamp'] as String?;
      final commentsJson = cachedData['comments'] as List<dynamic>?;

      if (timestampStr == null || commentsJson == null) {
        // Corrupted cache entry - delete it
        await _commentsCache?.delete(cacheKey);
        return null;
      }

      // Check TTL (15 minutes)
      final timestamp = DateTime.parse(timestampStr);
      final age = DateTime.now().difference(timestamp);

      if (age > _cacheTTL) {
        // Cache expired - delete and return null
        await _commentsCache?.delete(cacheKey);
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
      return null;
    }
  }

  /// Cache comments for an event
  ///
  /// Stores comments with current timestamp for TTL enforcement.
  /// Overwrites existing cache for the same event_id.
  Future<void> cacheComments({
    required String eventId,
    required List<CommentModel> comments,
  }) async {
    try {
      await _ensureInitialized();
      final cacheKey = 'event_$eventId';

      // Serialize comments to JSON
      final commentsJson = comments.map((c) => c.toJson()).toList();

      // Create cache entry with timestamp
      final cacheEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'comments': commentsJson,
      };

      // Store in Hive
      await _commentsCache?.put(cacheKey, cacheEntry);
    } catch (e) {
      // Hive error (disk full, permissions, etc.)
      // Caching is best-effort, so we ignore errors
    }
  }

  /// Clear all cached comments
  ///
  /// Used when user logs out or for cache management.
  Future<void> clearCache() async {
    try {
      await _ensureInitialized();
      await _commentsCache?.clear();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  /// Clear expired cache entries
  ///
  /// Should be called periodically (e.g., on app startup) to prevent cache bloat.
  Future<void> cleanupExpiredCache() async {
    try {
      await _ensureInitialized();
      final cache = _commentsCache;
      if (cache == null) return;

      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final key in cache.keys) {
        final cachedData = cache.get(key);
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
        await cache.delete(key);
      }
    } catch (e) {
      // Ignore errors when cleaning up cache
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
      await _ensureInitialized();
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
      await _offlineQueue?.put(action.tempId, actionJson);
    } catch (e) {
      // Hive error - ignore
    }
  }

  /// Get all queued offline actions
  ///
  /// Returns actions in FIFO order (oldest first).
  Future<List<OfflineCommentAction>> getOfflineQueue() async {
    try {
      await _ensureInitialized();
      final queue = _offlineQueue;
      if (queue == null) return [];

      final actions = <OfflineCommentAction>[];

      for (final actionJson in queue.values) {
        final action = _parseOfflineAction(actionJson);
        if (action != null) {
          actions.add(action);
        }
      }

      // Sort by queued_at (FIFO)
      actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      return actions;
    } catch (e) {
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
      await _ensureInitialized();
      await _offlineQueue?.delete(tempId);
    } catch (e) {
      // Ignore errors when removing from queue
    }
  }

  /// Clear entire offline queue
  ///
  /// Used after successful sync or on user request.
  Future<void> clearOfflineQueue() async {
    try {
      await _ensureInitialized();
      await _offlineQueue?.clear();
    } catch (e) {
      // Ignore errors when clearing queue
    }
  }

  /// Get offline queue size
  ///
  /// Useful for UI indicators ("X pending actions").
  int getQueueSize() {
    try {
      return _offlineQueue?.length ?? 0;
    } catch (e) {
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
      await _commentsCache?.close();
      await _offlineQueue?.close();
    } catch (e) {
      // Ignore errors when closing boxes
    }
  }
}
