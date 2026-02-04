// =====================================================================
// ModeratorCard Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display moderator info with stats and remove button
// Architecture: Card widget showing moderator performance metrics
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';
import 'package:nova/features/admin/presentation/providers/admin_actions_notifier.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';

/// Moderator card widget
///
/// Displays moderator info with statistics:
/// - Name, class, email
/// - Reviews this week, total reviews
/// - Approval rate percentage
/// - Last activity timestamp
/// - Remove role button
class ModeratorCard extends ConsumerWidget {
  final Moderator moderator;

  const ModeratorCard({
    super.key,
    required this.moderator,
  });

  Future<void> _removeModerator(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog (T064)
    final confirmed = await _showDemotionDialog(context);

    if (confirmed == true && context.mounted) {
      await ref.read(adminActionsNotifierProvider.notifier).removeUser(
            moderator.userId,
            moderator.fullName,
          );

      // Show success/error message
      if (context.mounted) {
        final actionsState = ref.read(adminActionsNotifierProvider);
        if (actionsState.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(actionsState.successMessage!),
              backgroundColor: NovaColors.success(context),
            ),
          );
        } else if (actionsState.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(actionsState.error!),
              backgroundColor: NovaColors.error(context),
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showDemotionDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi ruolo moderatore'),
        content: Text(
          '${moderator.fullName} perderà accesso alla dashboard moderazione. Le statistiche saranno archiviate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: NovaColors.error(context),
            ),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if inactive (last review >7 days ago)
    final isInactive = moderator.lastReviewAt != null &&
        DateTime.now().difference(moderator.lastReviewAt!).inDays > 7;

    return Container(
      padding: const EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and class
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          moderator.fullName,
                          style: NovaTextStyles.h3,
                        ),
                        if (isInactive) ...[
                          const SizedBox(width: NovaSpacing.xs),
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: NovaColors.warning(context),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: NovaSpacing.xxs),
                    Text(
                      moderator.className,
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              AdaptiveButton(
                onPressed: () => _removeModerator(context, ref),
                type: AdaptiveButtonType.destructive,
                child: const Text('Rimuovi'),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.m),

          // Email
          Text(
            moderator.email,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textTertiary(context),
            ),
          ),

          const SizedBox(height: NovaSpacing.m),

          // Statistics grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Questa settimana',
                  value: '${moderator.reviewsThisWeek}',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Totale',
                  value: '${moderator.totalReviews}',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Approvazioni',
                  value: '${moderator.approvalRatePercent.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.m),

          // Last activity
          if (moderator.lastReviewAt != null)
            Text(
              'Ultima attività: ${moderator.lastActivityText}',
              style: NovaTextStyles.caption.copyWith(
                color: isInactive
                    ? NovaColors.warning(context)
                    : NovaColors.textTertiary(context),
              ),
            )
          else
            Text(
              'Nessuna attività',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiary(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// Internal widget for displaying a stat item
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: NovaTextStyles.h2,
        ),
        const SizedBox(height: NovaSpacing.xxs),
        Text(
          label,
          style: NovaTextStyles.caption.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
