// Widget: EventStatusBadge
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Visual badge showing event moderation status
//
// Status colors:
// - Pending: Yellow badge with "In Revisione" text + clock icon
// - Approved: Green badge with "Approvato" text + check icon
// - Rejected: Red badge with "Rifiutato" text + X icon

import 'package:flutter/material.dart';
import '../../domain/entities/event_status.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';

/// Status badge for event moderation status
class EventStatusBadge extends StatelessWidget {
  final EventStatus status;
  final bool compact;

  const EventStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? NovaSpacing.small : NovaSpacing.medium,
        vertical: compact ? NovaSpacing.xsmall : NovaSpacing.small,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(NovaRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: compact ? 14 : 16,
            color: _getTextColor(context),
          ),
          SizedBox(width: NovaSpacing.xsmall),
          Text(
            status.label,
            style:
                (compact ? NovaTypography.bodySmall : NovaTypography.bodyMedium)
                    .copyWith(
              color: _getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Get background color based on status
  Color _getBackgroundColor(BuildContext context) {
    switch (status) {
      case EventStatus.pending:
        return NovaColors.eventPendingBackground;
      case EventStatus.approved:
        return NovaColors.eventApprovedBackground;
      case EventStatus.rejected:
        return NovaColors.eventRejectedBackground;
    }
  }

  /// Get text/icon color based on status
  Color _getTextColor(BuildContext context) {
    switch (status) {
      case EventStatus.pending:
        return NovaColors.eventPendingText;
      case EventStatus.approved:
        return NovaColors.eventApprovedText;
      case EventStatus.rejected:
        return NovaColors.eventRejectedText;
    }
  }

  /// Get icon based on status
  IconData _getIcon() {
    switch (status) {
      case EventStatus.pending:
        return Icons.schedule_outlined; // Clock icon
      case EventStatus.approved:
        return Icons.check_circle_outline; // Check icon
      case EventStatus.rejected:
        return Icons.cancel_outlined; // X icon
    }
  }
}
