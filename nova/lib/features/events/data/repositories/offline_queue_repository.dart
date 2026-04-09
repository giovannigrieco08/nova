// Repository: OfflineQueueRepository
// Feature: 003-events-feed
// Purpose: Handle offline actions queue with exponential backoff retry (1s, 2s, 4s)

import 'dart:async';
import '../../domain/entities/offline_action.dart';
import '../data_sources/events_local_data_source.dart';
import '../data_sources/events_remote_data_source.dart';

class OfflineQueueRepository {
  final EventsLocalDataSource _localDataSource;
  final EventsRemoteDataSource _remoteDataSource;

  // Retry timer for background processing
  Timer? _retryTimer;

  // Callback for failed actions (to show notification)
  Function(List<OfflineAction>)? onFailedActionsExceedRetries;

  OfflineQueueRepository({
    required EventsLocalDataSource localDataSource,
    required EventsRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  // ========================================================================
  // QUEUE MANAGEMENT
  // ========================================================================

  /// Add action to offline queue
  Future<void> queueAction(OfflineAction action) async {
    await _localDataSource.queueOfflineAction(action);
    // Try to process immediately (if online)
    await processQueue();
  }

  /// Process all queued actions with exponential backoff retry
  /// FR-010a: Auto-retry with exponential backoff (1s, 2s, 4s)
  Future<void> processQueue() async {
    final retryableActions = await _localDataSource.getRetryableActions();

    for (final action in retryableActions) {
      try {
        // Execute the action based on type
        await _executeAction(action);

        // Success - remove from queue
        await _localDataSource.removeOfflineAction(action.id);
      } catch (e) {
        // Failure - increment retry count
        final updatedAction = action.incrementRetry();
        await _localDataSource.updateOfflineAction(updatedAction);

        // Check if exceeded max retries (3 attempts)
        if (updatedAction.hasExceededMaxRetries) {
          // Notify user about failure (FR-010b)
          _notifyFailedActions();
        } else {
          // Schedule retry with exponential backoff
          _scheduleRetry(updatedAction);
        }
      }
    }
  }

  /// Execute a single offline action based on type
  Future<void> _executeAction(OfflineAction action) async {
    switch (action.type) {
      case 'like_event':
        await _remoteDataSource.likeEvent(
          eventId: action.payload['event_id'] as String,
          userId: action.payload['user_id'] as String,
        );
        break;

      case 'unlike_event':
        await _remoteDataSource.unlikeEvent(
          eventId: action.payload['event_id'] as String,
          userId: action.payload['user_id'] as String,
        );
        break;

      case 'participate_event':
        await _remoteDataSource.participateInEvent(
          eventId: action.payload['event_id'] as String,
          userId: action.payload['user_id'] as String,
        );
        break;

      case 'unparticipate_event':
        await _remoteDataSource.unparticipateFromEvent(
          eventId: action.payload['event_id'] as String,
          userId: action.payload['user_id'] as String,
        );
        break;

      case 'post_comment':
        await _remoteDataSource.postComment(
          eventId: action.payload['event_id'] as String,
          authorId: action.payload['author_id'] as String,
          text: action.payload['text'] as String,
        );
        break;

      case 'delete_comment':
        await _remoteDataSource.deleteComment(
          action.payload['comment_id'] as String,
        );
        break;

      case 'update_event':
        await _remoteDataSource.updateEvent(
          eventId: action.payload['event_id'] as String,
          updates: action.payload['updates'] as Map<String, dynamic>,
        );
        break;

      case 'delete_event':
        await _remoteDataSource.deleteEvent(
          action.payload['event_id'] as String,
        );
        break;

      case 'submit_report':
        await _remoteDataSource.submitReport(
          eventId: action.payload['event_id'] as String,
          reporterId: action.payload['reporter_id'] as String,
          reason: action.payload['reason'] as String,
          explanation: action.payload['explanation'] as String,
        );
        break;

      default:
        throw StateError('Unknown action type: ${action.type}');
    }
  }

  /// Schedule retry with exponential backoff delay
  /// FR-010a: Exponential backoff (1s, 2s, 4s)
  void _scheduleRetry(OfflineAction action) {
    _retryTimer?.cancel();
    _retryTimer = Timer(action.backoffDelay, () {
      processQueue();
    });
  }

  /// Notify about failed actions (exceeded max retries)
  /// FR-010b: Notification after 3 failed attempts
  void _notifyFailedActions() async {
    final failedActions = await _localDataSource.getFailedActions();
    if (failedActions.isNotEmpty && onFailedActionsExceedRetries != null) {
      onFailedActionsExceedRetries!(failedActions);
    }
  }

  // ========================================================================
  // MANUAL RETRY (User-triggered)
  // ========================================================================

  /// Manually retry all failed actions (triggered by user from notification)
  /// FR-010b: Manual retry button
  Future<void> retryFailedActions() async {
    final failedActions = await _localDataSource.getFailedActions();

    for (final action in failedActions) {
      // Reset retry count
      final resetAction = action.copyWith(
        retryCount: 0,
        lastRetryAt: null,
      );
      await _localDataSource.updateOfflineAction(resetAction);
    }

    // Process queue again
    await processQueue();
  }

  /// Retry single action (for granular retry)
  Future<void> retryAction(String actionId) async {
    final actions = await _localDataSource.getQueuedActions();
    final action = actions.firstWhere((a) => a.id == actionId);

    // Reset retry count
    final resetAction = action.copyWith(
      retryCount: 0,
      lastRetryAt: null,
    );
    await _localDataSource.updateOfflineAction(resetAction);

    // Try to execute immediately
    try {
      await _executeAction(resetAction);
      await _localDataSource.removeOfflineAction(resetAction.id);
    } catch (e) {
      // Re-queue with retry
      final updatedAction = resetAction.incrementRetry();
      await _localDataSource.updateOfflineAction(updatedAction);
    }
  }

  // ========================================================================
  // QUEUE STATUS
  // ========================================================================

  /// Get all queued actions (for debugging or display)
  Future<List<OfflineAction>> getQueuedActions() async {
    return _localDataSource.getQueuedActions();
  }

  /// Get count of pending actions
  Future<int> getPendingActionsCount() async {
    return _localDataSource.getQueueSize();
  }

  /// Get count of failed actions (exceeded max retries)
  Future<int> getFailedActionsCount() async {
    final failedActions = await _localDataSource.getFailedActions();
    return failedActions.length;
  }

  /// Check if there are any pending actions
  Future<bool> hasPendingActions() async {
    return _localDataSource.hasPendingActions();
  }

  /// Clear all queued actions (dangerous - only for debugging)
  Future<void> clearQueue() async {
    await _localDataSource.clearOfflineQueue();
  }

  // ========================================================================
  // LIFECYCLE
  // ========================================================================

  /// Start background retry processing (call on app resume)
  void startBackgroundProcessing() {
    processQueue();
  }

  /// Stop background retry processing (call on app pause)
  void stopBackgroundProcessing() {
    _retryTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
  }
}
