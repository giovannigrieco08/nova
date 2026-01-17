import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';

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

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _reactionsChannel;

  ChatRealtimeNotifier({
    required SupabaseClient supabase,
    required String currentUserId,
    required ChatRemoteDataSource dataSource,
  })  : _supabase = supabase,
        _currentUserId = currentUserId,
        _dataSource = dataSource,
        super(const ChatRealtimeState());

  /// Initialize realtime subscriptions
  Future<void> initialize() async {
    await _subscribeToMessages();
    await _subscribeToReactions();
    state = state.copyWith(isConnected: true);
  }

  /// Subscribe to message changes via Postgres Changes
  Future<void> _subscribeToMessages() async {
    _messagesChannel = _supabase
        .channel('global-chat:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            // Postgres Changes only returns raw row data without joins.
            // We need to re-fetch the message to get full data (profiles, media, etc.)
            final messageId = payload.newRecord['id'] as String;
            final fullMessage = await _dataSource.getMessage(messageId);
            if (fullMessage != null) {
              final message = fullMessage.toEntity(currentUserId: _currentUserId);
              _addMessage(message);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            // Re-fetch to get full joined data
            final messageId = payload.newRecord['id'] as String;
            final fullMessage = await _dataSource.getMessage(messageId);
            if (fullMessage != null) {
              final message = fullMessage.toEntity(currentUserId: _currentUserId);
              _updateMessage(message);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
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
  );

  // Initialize on creation
  notifier.initialize();

  return notifier;
});
