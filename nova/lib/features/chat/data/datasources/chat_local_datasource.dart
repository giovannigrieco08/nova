import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Local data source for chat offline support.
///
/// Manages pending messages that couldn't be sent due to:
/// - Network connectivity issues
/// - Rate limiting (queued for retry)
///
/// Messages are stored in Hive and synced when connectivity returns.
class ChatLocalDataSource {
  static const String _boxName = 'chat_pending_messages';

  late Box<Map> _box;
  bool _isInitialized = false;

  /// Default constructor.
  ChatLocalDataSource();

  /// Test-only constructor that injects a pre-opened box.
  @visibleForTesting
  ChatLocalDataSource.withBox(Box<Map> box)
      : _box = box,
        _isInitialized = true;

  /// Initialize Hive box for pending messages.
  Future<void> init() async {
    if (_isInitialized) return;

    _box = await Hive.openBox<Map>(_boxName);
    _isInitialized = true;
  }

  /// Ensure initialized before operations.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'ChatLocalDataSource not initialized. Call init() first.');
    }
  }

  /// Add a message to the pending queue.
  ///
  /// Called when sending fails due to network issues.
  /// Returns the local ID used to track the message.
  Future<String> addPendingMessage({
    required String content,
    required String userId,
    String? replyToId,
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    _ensureInitialized();

    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final pendingMessage = {
      'local_id': localId,
      'content': content,
      'user_id': userId,
      'reply_to_id': replyToId,
      'mentions': mentions,
      'status': PendingMessageStatus.pending.name,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'last_error': null,
    };

    await _box.put(localId, pendingMessage);
    return localId;
  }

  /// Get all pending messages ordered by creation time.
  List<PendingMessage> getPendingMessages() {
    _ensureInitialized();

    final messages = _box.values
        .map((map) => PendingMessage.fromMap(Map<String, dynamic>.from(map)))
        .toList();

    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  /// Update the status of a pending message.
  Future<void> updateMessageStatus(
    String localId,
    PendingMessageStatus status, {
    String? error,
    String? serverId,
  }) async {
    _ensureInitialized();

    final message = _box.get(localId);
    if (message == null) return;

    final updatedMessage = Map<String, dynamic>.from(message);
    updatedMessage['status'] = status.name;
    if (error != null) {
      updatedMessage['last_error'] = error;
      updatedMessage['retry_count'] = (message['retry_count'] as int? ?? 0) + 1;
    }
    if (serverId != null) {
      updatedMessage['server_id'] = serverId;
    }

    await _box.put(localId, updatedMessage);
  }

  /// Remove a successfully synced message.
  Future<void> removePendingMessage(String localId) async {
    _ensureInitialized();
    await _box.delete(localId);
  }

  /// Clear all pending messages.
  ///
  /// Use with caution - called when user logs out.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _box.clear();
  }

  /// Check if there are pending messages to sync.
  bool hasPendingMessages() {
    _ensureInitialized();
    return _box.isNotEmpty;
  }

  /// Get count of pending messages.
  int getPendingCount() {
    _ensureInitialized();
    return _box.length;
  }

  /// Get messages that should be retried.
  ///
  /// Filters out messages with too many retries or permanent errors.
  List<PendingMessage> getMessagesForRetry({int maxRetries = 3}) {
    return getPendingMessages()
        .where((m) =>
            m.status == PendingMessageStatus.pending &&
            m.retryCount < maxRetries)
        .toList();
  }

  /// Mark a message as failed (won't retry).
  Future<void> markAsFailed(String localId, String reason) async {
    await updateMessageStatus(
      localId,
      PendingMessageStatus.failed,
      error: reason,
    );
  }

  /// Clean up old failed messages (older than 24 hours).
  Future<void> cleanupOldMessages() async {
    _ensureInitialized();

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final keysToDelete = <dynamic>[];

    for (final entry in _box.toMap().entries) {
      final message = Map<String, dynamic>.from(entry.value);
      final createdAt = DateTime.parse(message['created_at'] as String);

      if (createdAt.isBefore(cutoff)) {
        keysToDelete.add(entry.key);
      }
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
    }
  }
}

/// Status of a pending message in the queue.
enum PendingMessageStatus {
  /// Waiting to be sent
  pending,

  /// Currently being sent
  sending,

  /// Successfully sent and synced
  synced,

  /// Failed after max retries
  failed,

  /// Rate limited - will retry after delay
  rateLimited,
}

/// A pending message waiting to be synced.
class PendingMessage {
  final String localId;
  final String content;
  final String userId;
  final String? replyToId;
  final List<Map<String, dynamic>> mentions;
  final PendingMessageStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final String? serverId;

  const PendingMessage({
    required this.localId,
    required this.content,
    required this.userId,
    this.replyToId,
    required this.mentions,
    required this.status,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
    this.serverId,
  });

  factory PendingMessage.fromMap(Map<String, dynamic> map) {
    return PendingMessage(
      localId: map['local_id'] as String,
      content: map['content'] as String,
      userId: map['user_id'] as String,
      replyToId: map['reply_to_id'] as String?,
      mentions: (map['mentions'] as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList(),
      status: PendingMessageStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? 'pending'),
        orElse: () => PendingMessageStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
      serverId: map['server_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'local_id': localId,
        'content': content,
        'user_id': userId,
        'reply_to_id': replyToId,
        'mentions': mentions,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'server_id': serverId,
      };

  /// Whether this message is still waiting to be sent
  bool get isPending =>
      status == PendingMessageStatus.pending ||
      status == PendingMessageStatus.rateLimited;

  /// Whether this message can be retried
  bool get canRetry => retryCount < 3 && isPending;

  PendingMessage copyWith({
    String? localId,
    String? content,
    String? userId,
    String? replyToId,
    List<Map<String, dynamic>>? mentions,
    PendingMessageStatus? status,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    String? serverId,
  }) {
    return PendingMessage(
      localId: localId ?? this.localId,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      replyToId: replyToId ?? this.replyToId,
      mentions: mentions ?? this.mentions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      serverId: serverId ?? this.serverId,
    );
  }
}
