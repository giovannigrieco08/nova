// =====================================================================
// Rejection Reason Badge Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display rejection reason for rejected events
// Architecture: Stateless widget with error styling
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Badge displaying why an event was rejected
///
/// Shows rejection reason with error styling (red background + icon).
/// Used in ProfileScreen to show feedback from moderators.
class RejectionReasonBadge extends StatelessWidget {
  final String rejectionReason;
  final bool expanded;

  const RejectionReasonBadge({
    super.key,
    required this.rejectionReason,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.error(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(NovaRadius.m),
        border: Border.all(
          color: NovaColors.error(context).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: NovaColors.error(context),
          ),
          const SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivo rifiuto',
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.error(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: NovaSpacing.xs),
                Text(
                  rejectionReason,
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
