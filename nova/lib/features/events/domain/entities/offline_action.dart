// Domain Entity: OfflineAction
// Feature: 003-events-feed
// Purpose: Queue for offline actions with exponential backoff retry

import 'package:hive/hive.dart';

part 'offline_action.g.dart';

@HiveType(typeId: 7) // Hive type adapter ID
class OfflineAction {
  @HiveField(0)
  final String id; // Unique action ID (UUID)

  @HiveField(1)
  final String type; // Action type: like_event, unlike_event, participate_event, post_comment, etc.

  @HiveField(2)
  final Map<String, dynamic> payload; // Action-specific data (event_id, user_id, comment_text, etc.)

  @HiveField(3)
  final DateTime queuedAt; // When action was queued

  @HiveField(4)
  final int retryCount; // Number of retry attempts (max 3)

  @HiveField(5)
  final DateTime? lastRetryAt; // Last retry timestamp (null if never retried)

  OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastRetryAt,
  });

  /// Create new offline action with generated ID
  factory OfflineAction.create({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return OfflineAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
      type: type,
      payload: payload,
      queuedAt: DateTime.now(),
      retryCount: 0,
    );
  }

  /// CopyWith for retry updates
  OfflineAction copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? payload,
    DateTime? queuedAt,
    int? retryCount,
    DateTime? lastRetryAt,
  }) {
    return OfflineAction(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
    );
  }

  /// Increment retry count and update last retry timestamp
  OfflineAction incrementRetry() {
    return copyWith(
      retryCount: retryCount + 1,
      lastRetryAt: DateTime.now(),
    );
  }

  /// Check if action has exceeded max retries (3 attempts)
  bool get hasExceededMaxRetries => retryCount >= 3;

  /// Get exponential backoff delay (1s, 2s, 4s)
  Duration get backoffDelay {
    if (retryCount == 0) return const Duration(seconds: 1);
    if (retryCount == 1) return const Duration(seconds: 2);
    return const Duration(seconds: 4); // retryCount >= 2
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OfflineAction(id: $id, type: $type, retryCount: $retryCount, hasExceededMaxRetries: $hasExceededMaxRetries)';
  }
}
