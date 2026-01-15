import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/shared/widgets/avatar_widget.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// Bottom sheet showing who reacted to a message.
///
/// Displays reactions grouped by emoji with user avatars and names.
class ChatReactionDetailSheet extends ConsumerWidget {
  final String messageId;
  final Map<String, int> reactionCounts;

  const ChatReactionDetailSheet({
    super.key,
    required this.messageId,
    required this.reactionCounts,
  });

  /// Show the reaction detail sheet
  static void show(
    BuildContext context, {
    required String messageId,
    required Map<String, int> reactionCounts,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => ChatReactionDetailSheet(
        messageId: messageId,
        reactionCounts: reactionCounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(reactionsWithUsersProvider(messageId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: NovaSpacing.s),
            decoration: BoxDecoration(
              color: NovaColors.border(context),
              borderRadius: NovaRadius.circularXxs,
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.all(NovaSpacing.m),
            child: Text(
              'Reazioni',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
          ),

          Divider(height: 1, color: NovaColors.border(context)),

          // Content
          Flexible(
            child: reactionsAsync.when(
              data: (reactions) => _buildContent(context, reactions),
              loading: () => _buildLoading(context),
              error: (error, _) => _buildError(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<ReactionWithUserInfo> reactions) {
    if (reactions.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(NovaSpacing.xl),
        child: Text(
          'Nessuna reazione',
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
      );
    }

    // Group reactions by emoji
    final groupedReactions = <String, List<ReactionWithUserInfo>>{};
    for (final reaction in reactions) {
      groupedReactions.putIfAbsent(reaction.emoji, () => []);
      groupedReactions[reaction.emoji]!.add(reaction);
    }

    // Sort by count (same order as reactionCounts)
    final sortedEmojis = reactionCounts.keys.toList();

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: NovaSpacing.s),
      itemCount: sortedEmojis.length,
      itemBuilder: (context, index) {
        final emoji = sortedEmojis[index];
        final users = groupedReactions[emoji] ?? [];
        if (users.isEmpty) return const SizedBox.shrink();

        return _EmojiSection(
          emoji: emoji,
          emojiLabel: ChatEmoji.labelFor(emoji),
          users: users,
        );
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.xl),
      child: CircularProgressIndicator(
        color: NovaColors.primary(context),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: NovaColors.error(context),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Errore nel caricamento',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing users who reacted with a specific emoji
class _EmojiSection extends StatelessWidget {
  final String emoji;
  final String emojiLabel;
  final List<ReactionWithUserInfo> users;

  const _EmojiSection({
    required this.emoji,
    required this.emojiLabel,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoji header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              SizedBox(width: NovaSpacing.s),
              Text(
                emojiLabel,
                style: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: NovaSpacing.xs),
              Text(
                '(${users.length})',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textTertiary(context),
                ),
              ),
            ],
          ),
        ),

        // User list
        ...users.map((user) => _UserTile(user: user)),

        SizedBox(height: NovaSpacing.s),
      ],
    );
  }
}

/// Tile showing a user who reacted
class _UserTile extends StatelessWidget {
  final ReactionWithUserInfo user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.xs,
      ),
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: user.avatarUrl,
            name: user.fullName,
            size: 36,
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              user.fullName,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
