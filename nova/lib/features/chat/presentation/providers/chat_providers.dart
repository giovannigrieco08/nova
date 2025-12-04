import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';

// =============================================================================
// Core Providers
// =============================================================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Current user ID provider
final currentUserIdProvider = Provider<String>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id ?? '';
});

/// Hive box for pending messages (offline queue)
/// Note: Box is opened in main.dart before runApp(), so it's guaranteed to be available
final pendingMessagesBoxProvider =
    Provider<Box<Map<dynamic, dynamic>>>((ref) {
  return Hive.box<Map<dynamic, dynamic>>('chat_pending_messages');
});

// =============================================================================
// Data Layer Providers
// =============================================================================

/// Remote data source provider
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ChatRemoteDataSource(supabase);
});

/// Chat repository provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final box = ref.watch(pendingMessagesBoxProvider);

  return ChatRepositoryImpl(
    remoteDataSource: remoteDataSource,
    supabase: supabase,
    pendingMessagesBox: box,
  );
});

// =============================================================================
// Message Providers
// =============================================================================

/// Stream of chat messages (real-time)
final chatMessagesStreamProvider =
    StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchMessages(limit: 50);
});

/// Load more messages (pagination)
final loadMoreMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, DateTime>((ref, beforeTimestamp) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.loadMoreMessages(
    beforeTimestamp: beforeTimestamp,
    limit: 20,
  );
});

/// Get single message by ID
final chatMessageProvider =
    FutureProvider.autoDispose.family<ChatMessage?, String>((ref, messageId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessage(messageId);
});

// =============================================================================
// Compose State
// =============================================================================

/// State for the compose bar
class ComposeState {
  final String content;
  final String? replyToId;
  final ChatMessage? replyToMessage;
  final List<MentionSearchResult> mentionResults;
  final bool isShowingMentionPicker;
  final bool isSending;
  final String? error;

  const ComposeState({
    this.content = '',
    this.replyToId,
    this.replyToMessage,
    this.mentionResults = const [],
    this.isShowingMentionPicker = false,
    this.isSending = false,
    this.error,
  });

  ComposeState copyWith({
    String? content,
    String? replyToId,
    ChatMessage? replyToMessage,
    List<MentionSearchResult>? mentionResults,
    bool? isShowingMentionPicker,
    bool? isSending,
    String? error,
  }) {
    return ComposeState(
      content: content ?? this.content,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      mentionResults: mentionResults ?? this.mentionResults,
      isShowingMentionPicker: isShowingMentionPicker ?? this.isShowingMentionPicker,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }

  /// Clear reply state
  ComposeState clearReply() {
    return ComposeState(
      content: content,
      mentionResults: mentionResults,
      isShowingMentionPicker: isShowingMentionPicker,
      isSending: isSending,
      error: error,
    );
  }

  /// Clear all compose state
  ComposeState clear() {
    return const ComposeState();
  }
}

/// Compose state notifier
class ComposeStateNotifier extends StateNotifier<ComposeState> {
  final ChatRepository _repository;

  ComposeStateNotifier(this._repository) : super(const ComposeState());

  void updateContent(String content) {
    state = state.copyWith(content: content);
  }

  void setReplyTo(ChatMessage message) {
    state = state.copyWith(
      replyToId: message.id,
      replyToMessage: message,
    );
  }

  void clearReply() {
    state = state.clearReply();
  }

  void showMentionPicker(List<MentionSearchResult> results) {
    state = state.copyWith(
      mentionResults: results,
      isShowingMentionPicker: true,
    );
  }

  void hideMentionPicker() {
    state = state.copyWith(
      mentionResults: [],
      isShowingMentionPicker: false,
    );
  }

  Future<void> searchMentions(String query) async {
    if (query.isEmpty) {
      hideMentionPicker();
      return;
    }

    try {
      final results = await _repository.searchUsersForMention(query);
      showMentionPicker(results);
    } catch (e) {
      hideMentionPicker();
    }
  }

  Future<bool> sendMessage({
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    if (state.content.trim().isEmpty) return false;
    if (state.isSending) return false;

    state = state.copyWith(isSending: true, error: null);

    try {
      await _repository.sendMessage(
        content: state.content.trim(),
        mentions: mentions,
        replyToId: state.replyToId,
      );
      state = state.clear();
      return true;
    } on ChatRateLimitException catch (e) {
      state = state.copyWith(isSending: false, error: e.message);
      return false;
    } on ChatProfanityException catch (e) {
      state = state.copyWith(isSending: false, error: e.message);
      return false;
    } catch (e, stackTrace) {
      // DEBUG: Stampa errore reale in console
      print('=== CHAT SEND ERROR ===');
      print('Error: $e');
      print('Stack: $stackTrace');
      print('=======================');

      state = state.copyWith(
        isSending: false,
        error: 'Errore nell\'invio del messaggio. Riprova.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Compose state provider
final composeStateProvider =
    StateNotifierProvider.autoDispose<ComposeStateNotifier, ComposeState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ComposeStateNotifier(repository);
});

// =============================================================================
// Reaction Providers
// =============================================================================

/// Add reaction to a message
final addReactionProvider =
    FutureProvider.autoDispose.family<void, ({String messageId, String emoji})>(
        (ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  await repository.addReaction(
    messageId: params.messageId,
    emoji: params.emoji,
  );
});

/// Remove reaction from a message
final removeReactionProvider =
    FutureProvider.autoDispose.family<void, ({String messageId, String emoji})>(
        (ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  await repository.removeReaction(
    messageId: params.messageId,
    emoji: params.emoji,
  );
});

// =============================================================================
// Report Providers
// =============================================================================

/// Submit a report
final submitReportProvider = FutureProvider.autoDispose
    .family<bool, ({String messageId, ChatReportReason reason})>(
        (ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.submitReport(
    messageId: params.messageId,
    reason: params.reason,
  );
});

/// Check if user has reported a message
final hasUserReportedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, messageId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.hasUserReported(messageId);
});

// =============================================================================
// Media Upload Providers
// =============================================================================

/// Upload media (image, video, audio) to chat
///
/// [maxViews] determines how many times the media can be viewed (1 or 2).
final uploadMediaProvider = FutureProvider.autoDispose
    .family<ChatMediaInfo, ({String filePath, ChatMediaType mediaType, int maxViews})>(
        (ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.uploadMedia(
    filePath: params.filePath,
    mediaType: params.mediaType,
    maxViews: params.maxViews,
  );
});

/// Get a signed URL for viewing media (60 second expiry)
final signedMediaUrlProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, mediaId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getSignedMediaUrl(mediaId);
});

/// Mark media as viewed and get updated info
final markMediaViewedProvider = FutureProvider.autoDispose
    .family<ChatMediaInfo?, String>((ref, mediaId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.markMediaViewed(mediaId);
});

// =============================================================================
// Reaction Detail Providers
// =============================================================================

/// Get reactions with user info for a message (for detail sheet)
final reactionsWithUsersProvider = FutureProvider.autoDispose
    .family<List<ReactionWithUserInfo>, String>((ref, messageId) async {
  final dataSource = ref.watch(chatRemoteDataSourceProvider);
  final reactions = await dataSource.getReactionsWithUsers(messageId);

  return reactions.map((r) => ReactionWithUserInfo(
    emoji: r.emoji,
    userId: r.userId,
    fullName: r.fullName,
    avatarUrl: r.avatarUrl,
  )).toList();
});

/// Reaction with user info for display
class ReactionWithUserInfo {
  final String emoji;
  final String userId;
  final String fullName;
  final String? avatarUrl;

  const ReactionWithUserInfo({
    required this.emoji,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
  });
}
