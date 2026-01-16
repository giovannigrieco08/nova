import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/providers/chat_realtime_provider.dart';
import 'package:nova/features/chat/presentation/providers/typing_indicator_provider.dart';
import 'package:nova/features/chat/presentation/widgets/chat_message_list.dart';
import 'package:nova/features/chat/presentation/widgets/chat_message_skeleton.dart';
import 'package:nova/features/chat/presentation/widgets/chat_compose_bar.dart';
import 'package:nova/features/chat/presentation/widgets/chat_typing_indicator.dart';
import 'package:nova/features/chat/presentation/widgets/chat_report_dialog.dart';
import 'package:nova/features/profile/presentation/providers/connectivity_provider.dart';

/// Main screen for the Global Chat feature.
///
/// Displays:
/// - App bar with chat title and connection status
/// - Real-time message list
/// - Typing indicator
/// - Compose bar with reply preview
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  ChatMessage? _replyToMessage;

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesStreamProvider);
    final realtimeState = ref.watch(chatRealtimeProvider);
    final typingState = ref.watch(typingIndicatorProvider);
    final composeState = ref.watch(composeStateProvider);
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final failedMessages = ref.watch(failedMessagesProvider);

    final isOnline = isOnlineAsync.whenOrNull(data: (v) => v) ?? true;
    final isConnecting = !realtimeState.isConnected;

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: NovaColors.textPrimary(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Indietro',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat',
              style: NovaTypography.headingMedium.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            if (isConnecting && isOnline)
              Text(
                'Connessione...',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textTertiary(context),
                ),
              )
            else if (!isOnline)
              Text(
                'Offline',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.warning(context),
                ),
              ),
          ],
        ),
        actions: [
          // Connection status indicator
          if (isConnecting && isOnline)
            Padding(
              padding: EdgeInsets.only(right: NovaSpacing.m),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NovaColors.textTertiary(context),
                ),
              ),
            )
          else if (!isOnline)
            Padding(
              padding: EdgeInsets.only(right: NovaSpacing.m),
              child: Icon(
                Icons.cloud_off,
                size: 20,
                color: NovaColors.warning(context),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (!isOnline) _buildOfflineBanner(context),

          // Rate limit error banner
          if (composeState.error != null &&
              composeState.error!.contains('rate limit'))
            _buildRateLimitBanner(context, composeState.error!),

          // Message list
          // Use realtime messages for display (receives live updates)
          // FutureProvider handles initial load and populates realtime state
          Expanded(
            child: messagesAsync.when(
              data: (_) => ChatMessageList(
                // Use realtime state for messages (live updates)
                messages: realtimeState.messages,
                failedMessages: failedMessages,
                isLoading: false,
                hasMore: realtimeState.messages.length >= 50,
                onLoadMore: () => _loadMoreMessages(realtimeState.messages),
                onRefresh: () => ref.refresh(chatMessagesStreamProvider),
                onReply: _setReplyTo,
                onReport: _showReportDialog,
                onReact: _toggleReaction,
              ),
              loading: () => const ChatMessageListSkeleton(),
              error: (error, stack) => _buildErrorState(context, error.toString()),
            ),
          ),

          // Typing indicator
          if (typingState.hasTypingUsers)
            ChatTypingIndicator(
              typingText: typingState.typingText,
            ),

          // Compose bar
          ChatComposeBar(
            replyTo: _replyToMessage,
            onCancelReply: _clearReplyTo,
            onSent: _onMessageSent,
          ),
        ],
      ),
    );
  }

  void _setReplyTo(ChatMessage message) {
    setState(() => _replyToMessage = message);
    ref.read(composeStateProvider.notifier).setReplyTo(message);
  }

  void _clearReplyTo() {
    setState(() => _replyToMessage = null);
    ref.read(composeStateProvider.notifier).clearReply();
  }

  void _onMessageSent() {
    _clearReplyTo();
  }

  Future<void> _loadMoreMessages(List<ChatMessage> currentMessages) async {
    if (currentMessages.isEmpty) return;

    final oldestMessage = currentMessages.last;
    await ref.read(
      loadMoreMessagesProvider(oldestMessage.createdAt).future,
    );
  }

  void _showReportDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder: (dialogContext) => ChatReportDialog(
        messageId: message.id,
        onReported: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Segnalazione inviata'),
              backgroundColor: NovaColors.success(context),
            ),
          );
        },
        onAlreadyReported: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hai già segnalato questo messaggio'),
              backgroundColor: NovaColors.warning(context),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final hasReaction = message.currentUserReactions.contains(emoji);

    try {
      if (hasReaction) {
        await ref.read(
          removeReactionProvider((messageId: message.id, emoji: emoji)).future,
        );
        ref
            .read(chatRealtimeProvider.notifier)
            .broadcastReactionRemoved(messageId: message.id, emoji: emoji);
      } else {
        await ref.read(
          addReactionProvider((messageId: message.id, emoji: emoji)).future,
        );
        ref
            .read(chatRealtimeProvider.notifier)
            .broadcastReactionAdded(messageId: message.id, emoji: emoji);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nella reazione'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      color: NovaColors.warning(context).withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: NovaColors.warning(context),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              'Sei offline. I messaggi verranno inviati quando tornerai online.',
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.warning(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateLimitBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      color: NovaColors.error(context).withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            size: 18,
            color: NovaColors.error(context),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              'Stai inviando messaggi troppo velocemente. Attendi qualche secondo.',
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.error(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: NovaColors.error(context),
            ),
            onPressed: () =>
                ref.read(composeStateProvider.notifier).clearError(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Errore di connessione',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.xs),
            Text(
              error,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () => ref.refresh(chatMessagesStreamProvider),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
