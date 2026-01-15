import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/shared/widgets/avatar_widget.dart';

/// Mention autocomplete dropdown widget.
///
/// Displays a list of user suggestions when typing @mention.
/// Shows user avatar, full name, and class.
class MentionAutocomplete extends StatelessWidget {
  final List<MentionSearchResult> results;
  final ValueChanged<MentionSearchResult> onSelect;
  final VoidCallback? onDismiss;

  const MentionAutocomplete({
    super.key,
    required this.results,
    required this.onSelect,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: 200,
      ),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: NovaRadius.circularS,
        border: Border.all(
          color: NovaColors.border(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NovaColors.textPrimaryLight.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: NovaRadius.circularS,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: NovaSpacing.xs),
          itemCount: results.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: NovaColors.border(context),
          ),
          itemBuilder: (context, index) {
            final result = results[index];
            return _MentionResultTile(
              result: result,
              onTap: () => onSelect(result),
            );
          },
        ),
      ),
    );
  }
}

/// Single mention result tile
class _MentionResultTile extends StatelessWidget {
  final MentionSearchResult result;
  final VoidCallback onTap;

  const _MentionResultTile({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        child: Row(
          children: [
            // Avatar
            AvatarWidget(
              avatarUrl: result.avatarUrl,
              name: result.fullName,
              size: 36,
            ),
            SizedBox(width: NovaSpacing.s),

            // Name and class
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.fullName,
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.studentClass != null) ...[
                    SizedBox(height: 2),
                    Text(
                      result.studentClass!,
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // @ indicator
            Text(
              '@',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.primary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
