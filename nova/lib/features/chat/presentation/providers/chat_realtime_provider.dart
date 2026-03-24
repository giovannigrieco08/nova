import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:nova/features/safety/presentation/providers/block_provider.dart';

/// Manages Supabase Realtime subscriptions for the chat feature.
///
/// Uses a hybrid channel strategy:
/// - Postgres Changes: Message inserts/updates/deletes
/// - Broadcast: Reaction changes (lower latency)
/// - Presence: Typing indicators (see typing_indicator_provider.dart)
class ChatRealtimeNotifier extends StateNotifier<ChatRealtimeState> {
  final SupabaseClient _supabase;
  final String _currentUserId;
  final ChatRemoteDataSource _dataSource;
  final Ref _ref;

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _reactionsChannel;

  ChatRealtimeNotifier({
    required SupabaseClient supabase,
    required String currentUserId,
    required ChatRemoteDataSource dataSource,
    required Ref ref,
  })  : _supabase = supabase,
        _currentUserId = currentUserId,
        _dataSource = dataSource,
        _ref = ref,
        super(const ChatRealtimeState());

  /// Initialize realtime subscriptions
  Future<void> initialize() async {
    await _subscribeToMessages();
    await _subscribeToReactions();
    state = state.copyWith(isConnected: true);
  }

  /// Subscribe to message changes via Postgres Changes
  Future<void> _subscribeToMessages() async {
    debugPrint('[Realtime] Subscribing to message changes...');
    _messagesChannel = _supabase
        .channel('global-chat:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            debugPrint('[Realtime] INSERT event received');
            debugPrint('[Realtime] - newRecord: ${payload.newRecord}');
            // Postgres Changes only returns raw row data without joins.
            // We need to re-fetch the message to get full data (profiles, media, etc.)
            // Use unawaited Future to not block the callback
            _handleMessageInsert(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            debugPrint('[Realtime] UPDATE event received');
            debugPrint('[Realtime] - newRecord: ${payload.newRecord}');
            // Re-fetch to get full joined data
            _handleMessageUpdate(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            debugPrint('[Realtime] DELETE event received');
            final messageId = payload.oldRecord['id'] as String?;
            if (messageId != null) {
              _removeMessage(messageId);
            }
          },
        );

    _messagesChannel!.subscribe();
  }

  /// Subscribe to reaction changes via Broadcast channel
  Future<void> _subscribeToReactions() async {
    _reactionsChannel = _supabase
        .channel('global-chat:reactions')
        .onBroadcast(
          event: 'reaction_added',
          callback: (payload) {
            final messageId = payload['message_id'] as String;
            final emoji = payload['emoji'] as String;
            final userId = payload['user_id'] as String;
            _handleReactionAdded(messageId, emoji, userId);
          },
        )
        .onBroadcast(
          event: 'reaction_removed',
          callback: (payload) {
            final messageId = payload['message_id'] as String;
            final emoji = payload['emoji'] as String;
            final userId = payload['user_id'] as String;
            _handleReactionRemoved(messageId, emoji, userId);
          },
        );

    _reactionsChannel!.subscribe();
  }

  void _addMessage(ChatMessage message) {
    final messages = [...state.messages];
    // Insert at beginning (newest first)
    messages.insert(0, message);
    state = state.copyWith(messages: messages, incrementCounter: true);
  }

  void _updateMessage(ChatMessage message) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
      state = state.copyWith(messages: messages, incrementCounter: true);
    }
  }

  void _removeMessage(String messageId) {
    final messages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: messages, incrementCounter: true);
  }

  /// Handle message INSERT - fetch full data asynchronously
  Future<void> _handleMessageInsert(Map<String, dynamic> record) async {
    final messageId = record['id'] as String?;
    if (messageId == null) {
      debugPrint('[Realtime] _handleMessageInsert: missing id in record');
      return;
    }
    debugPrint('[Realtime] _handleMessageInsert: $messageId');
    try {
      debugPrint('[Realtime] Fetching full message data...');
      final fullMessage = await _dataSource.getMessage(messageId);
      if (fullMessage != null) {
        debugPrint(
            '[Realtime] Got message, hasMedia: ${fullMessage.mediaJson != null}');
        final message = fullMessage.toEntity(currentUserId: _currentUserId);

        // UGC Safety: Check if sender is blocked before adding message
        try {
          final blockedIds = await _ref.read(blockedUserIdsProvider.future);
          if (blockedIds.contains(message.userId)) {
            debugPrint(
                '[Realtime] Message from blocked user ${message.userId}, skipping');
            return;
          }
        } catch (e) {
          // If we can't check blocked status, still add the message
          debugPrint('[Realtime] Could not check blocked status: $e');
        }

        debugPrint(
            '[Realtime] Entity hasMedia: ${message.hasMedia}, media: ${message.media?.id}');
        _addMessage(message);
        debugPrint('[Realtime] Message added to state');
      } else {
        debugPrint('[Realtime] getMessage returned null!');
      }
    } catch (e, st) {
      debugPrint('[Realtime] ERROR in _handleMessageInsert: $e');
      debugPrint('[Realtime] Stack: $st');
    }
  }

  /// Handle message UPDATE - fetch full data asynchronously
  Future<void> _handleMessageUpdate(Map<String, dynamic> record) async {
    final messageId = record['id'] as String?;
    if (messageId == null) {
      debugPrint('[Realtime] _handleMessageUpdate: missing id in record');
      return;
    }
    debugPrint('[Realtime] _handleMessageUpdate: $messageId');
    try {
      debugPrint('[Realtime] Fetching full message data...');
      final fullMessage = await _dataSource.getMessage(messageId);
      if (fullMessage != null) {
        debugPrint(
            '[Realtime] Got message, content: "${fullMessage.content}", hasMedia: ${fullMessage.mediaJson != null}');
        final message = fullMessage.toEntity(currentUserId: _currentUserId);
        debugPrint(
            '[Realtime] Entity hasMedia: ${message.hasMedia}, media: ${message.media?.id}');
        _updateMessage(message);
        debugPrint('[Realtime] Message updated in state');
      } else {
        debugPrint('[Realtime] getMessage returned null!');
      }
    } catch (e, st) {
      debugPrint('[Realtime] ERROR in _handleMessageUpdate: $e');
      debugPrint('[Realtime] Stack: $st');
    }
  }

  void _handleReactionAdded(String messageId, String emoji, String userId) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final message = messages[index];
      final newCounts = Map<String, int>.from(message.reactionCounts);
      newCounts[emoji] = (newCounts[emoji] ?? 0) + 1;

      final newUserReactions = Set<String>.from(message.currentUserReactions);
      if (userId == _currentUserId) {
        newUserReactions.add(emoji);
      }

      messages[index] = message.copyWith(
        reactionCounts: newCounts,
        currentUserReactions: newUserReactions,
        reactionCount: message.reactionCount + 1,
      );
      state = state.copyWith(messages: messages, incrementCounter: true);
    }
  }

  void _handleReactionRemoved(String messageId, String emoji, String userId) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final message = messages[index];
      final newCounts = Map<String, int>.from(message.reactionCounts);
      final currentCount = newCounts[emoji] ?? 0;
      if (currentCount > 1) {
        newCounts[emoji] = currentCount - 1;
      } else {
        newCounts.remove(emoji);
      }

      final newUserReactions = Set<String>.from(message.currentUserReactions);
      if (userId == _currentUserId) {
        newUserReactions.remove(emoji);
      }

      messages[index] = message.copyWith(
        reactionCounts: newCounts,
        currentUserReactions: newUserReactions,
        reactionCount: (message.reactionCount - 1).clamp(0, 999999),
      );
      state = state.copyWith(messages: messages, incrementCounter: true);
    }
  }

  /// Add reaction locally and broadcast to other clients
  Future<void> broadcastReactionAdded({
    required String messageId,
    required String emoji,
  }) async {
    // Update local state immediately (optimistic update)
    _handleReactionAdded(messageId, emoji, _currentUserId);

    // Broadcast to other clients
    await _reactionsChannel?.sendBroadcastMessage(
      event: 'reaction_added',
      payload: {
        'message_id': messageId,
        'emoji': emoji,
        'user_id': _currentUserId,
      },
    );
  }

  /// Remove reaction locally and broadcast to other clients
  Future<void> broadcastReactionRemoved({
    required String messageId,
    required String emoji,
  }) async {
    // Update local state immediately (optimistic update)
    _handleReactionRemoved(messageId, emoji, _currentUserId);

    // Broadcast to other clients
    await _reactionsChannel?.sendBroadcastMessage(
      event: 'reaction_removed',
      payload: {
        'message_id': messageId,
        'emoji': emoji,
        'user_id': _currentUserId,
      },
    );
  }

  /// Set initial messages (from API load)
  void setMessages(List<ChatMessage> messages) {
    state = state.copyWith(messages: messages, incrementCounter: true);
  }

  /// Refresh a specific message by ID.
  ///
  /// Fetches the latest data for the message and updates it in state.
  /// Used after media upload to ensure the message displays immediately
  /// without relying on Supabase Realtime UPDATE events.
  Future<void> refreshMessage(String messageId) async {
    debugPrint('[Realtime] refreshMessage: $messageId');
    try {
      final fullMessage = await _dataSource.getMessage(messageId);
      if (fullMessage != null) {
        final message = fullMessage.toEntity(currentUserId: _currentUserId);
        debugPrint(
            '[Realtime] refreshMessage got message, hasMedia: ${message.hasMedia}');

        final messages = [...state.messages];
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          // Update existing message
          messages[index] = message;
          debugPrint(
              '[Realtime] refreshMessage: updated existing message at index $index');
        } else {
          // Add as new message (shouldn't happen normally, but handle it)
          messages.insert(0, message);
          debugPrint('[Realtime] refreshMessage: added as new message');
        }
        state = state.copyWith(messages: messages, incrementCounter: true);
      }
    } catch (e) {
      debugPrint('[Realtime] refreshMessage ERROR: $e');
    }
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _reactionsChannel?.unsubscribe();
    super.dispose();
  }
}

/// State for realtime chat
class ChatRealtimeState {
  final List<ChatMessage> messages;
  final bool isConnected;
  final String? error;

  /// Counter that increments on every state change to ensure UI rebuilds
  final int updateCounter;

  const ChatRealtimeState({
    this.messages = const [],
    this.isConnected = false,
    this.error,
    this.updateCounter = 0,
  });

  ChatRealtimeState copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    String? error,
    bool incrementCounter = false,
  }) {
    return ChatRealtimeState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      updateCounter: incrementCounter ? updateCounter + 1 : updateCounter,
    );
  }
}

/// Provider for realtime chat state
final chatRealtimeProvider =
    StateNotifierProvider.autoDispose<ChatRealtimeNotifier, ChatRealtimeState>(
        (ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final dataSource = ChatRemoteDataSource(supabase);

  final notifier = ChatRealtimeNotifier(
    supabase: supabase,
    currentUserId: currentUserId,
    dataSource: dataSource,
    ref: ref,
  );

  // Initialize on creation
  notifier.initialize();

  return notifier;
});
