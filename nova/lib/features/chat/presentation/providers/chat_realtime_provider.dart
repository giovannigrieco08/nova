import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/data/models/chat_message_model.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// Manages Supabase Realtime subscriptions for the chat feature.
///
/// Uses a hybrid channel strategy:
/// - Postgres Changes: Message inserts/updates/deletes
/// - Broadcast: Reaction changes (lower latency)
/// - Presence: Typing indicators (see typing_indicator_provider.dart)
class ChatRealtimeNotifier extends StateNotifier<ChatRealtimeState> {
  final SupabaseClient _supabase;
  final String _currentUserId;

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _reactionsChannel;

  ChatRealtimeNotifier({
    required SupabaseClient supabase,
    required String currentUserId,
  })  : _supabase = supabase,
        _currentUserId = currentUserId,
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
          callback: (payload) {
            final model = ChatMessageModel.fromJson(payload.newRecord);
            final message = model.toEntity(currentUserId: _currentUserId);
            _addMessage(message);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final model = ChatMessageModel.fromJson(payload.newRecord);
            final message = model.toEntity(currentUserId: _currentUserId);
            _updateMessage(message);
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

    await _messagesChannel!.subscribe();
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

    await _reactionsChannel!.subscribe();
  }

  void _addMessage(ChatMessage message) {
    final messages = [...state.messages];
    // Insert at beginning (newest first)
    messages.insert(0, message);
    state = state.copyWith(messages: messages);
  }

  void _updateMessage(ChatMessage message) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
      state = state.copyWith(messages: messages);
    }
  }

  void _removeMessage(String messageId) {
    final messages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: messages);
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
      state = state.copyWith(messages: messages);
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
      state = state.copyWith(messages: messages);
    }
  }

  /// Broadcast a reaction added event
  Future<void> broadcastReactionAdded({
    required String messageId,
    required String emoji,
  }) async {
    await _reactionsChannel?.sendBroadcastMessage(
      event: 'reaction_added',
      payload: {
        'message_id': messageId,
        'emoji': emoji,
        'user_id': _currentUserId,
      },
    );
  }

  /// Broadcast a reaction removed event
  Future<void> broadcastReactionRemoved({
    required String messageId,
    required String emoji,
  }) async {
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
    state = state.copyWith(messages: messages);
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

  const ChatRealtimeState({
    this.messages = const [],
    this.isConnected = false,
    this.error,
  });

  ChatRealtimeState copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    String? error,
  }) {
    return ChatRealtimeState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

/// Provider for realtime chat state
final chatRealtimeProvider =
    StateNotifierProvider.autoDispose<ChatRealtimeNotifier, ChatRealtimeState>(
        (ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  final notifier = ChatRealtimeNotifier(
    supabase: supabase,
    currentUserId: currentUserId,
  );

  // Initialize on creation
  notifier.initialize();

  return notifier;
});
