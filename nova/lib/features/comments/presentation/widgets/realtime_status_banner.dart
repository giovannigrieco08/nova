import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/realtime_comments_provider.dart';

/// RealtimeStatusBanner Widget
///
/// Shows a banner when real-time updates are unavailable.
/// Provides visual feedback and reconnection option.
///
/// **T088**: Connection health monitoring with banner
/// **T089**: Fallback to pull-to-refresh when realtime unavailable
///
/// Usage:
/// ```dart
/// RealtimeStatusBanner(
///   eventId: eventId,
///   onRetry: () => ref.read(realtimeCommentsProvider(eventId).notifier).reconnect(),
/// )
/// ```
class RealtimeStatusBanner extends ConsumerWidget {
  final String eventId;
  final VoidCallback? onRetry;

  const RealtimeStatusBanner({
    super.key,
    required this.eventId,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(realtimeCommentsProvider(eventId));

    // Only show banner for disconnected or error states
    if (state.status == RealtimeStatus.connected ||
        state.status == RealtimeStatus.connecting) {
      return const SizedBox.shrink();
    }

    final isError = state.status == RealtimeStatus.error;
    final backgroundColor = isError
        ? NovaColors.errorLight.withValues(alpha: 0.1)
        : NovaColors.warningLight.withValues(alpha: 0.1);
    final iconColor = isError ? NovaColors.errorLight : NovaColors.warningLight;
    final message = state.errorMessage ??
        'Aggiornamenti in tempo reale non disponibili. Usa pull-to-refresh.';

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.wifi_off,
              size: 20,
              color: iconColor,
            ),
            SizedBox(width: NovaSpacing.s),
            Expanded(
              child: Text(
                message,
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textSecondaryLight,
                ),
              ),
            ),
            if (onRetry != null && isError) ...[
              SizedBox(width: NovaSpacing.s),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.s,
                    vertical: NovaSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Riprova',
                    style: NovaTypography.bodySmall.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Connecting indicator widget
///
/// Shows a subtle loading indicator while connecting to realtime.
class RealtimeConnectingIndicator extends ConsumerWidget {
  final String eventId;

  const RealtimeConnectingIndicator({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(realtimeCommentsProvider(eventId));

    if (state.status != RealtimeStatus.connecting) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: NovaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NovaColors.primaryLight,
            ),
          ),
          SizedBox(width: NovaSpacing.xs),
          Text(
            'Connessione in corso...',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
