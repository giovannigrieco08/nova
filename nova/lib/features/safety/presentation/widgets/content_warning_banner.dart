import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/content_filter_provider.dart';

/// Banner showing content filter warnings or blocks
class ContentWarningBanner extends ConsumerWidget {
  const ContentWarningBanner({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkState = ref.watch(contentCheckNotifierProvider);

    // Don't show anything if clean or checking
    if (checkState.isClean && !checkState.isChecking) {
      return const SizedBox.shrink();
    }

    if (checkState.isChecking) {
      return _buildCheckingIndicator(context);
    }

    if (checkState.isBlocked) {
      return _buildBlockedBanner(context);
    }

    if (checkState.hasWarnings) {
      return _buildWarningBanner(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildCheckingIndicator(BuildContext context) {
    if (compact) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Verifica contenuto...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return Tooltip(
        message: 'Contenuto non consentito',
        child: Icon(
          Icons.block,
          color: theme.colorScheme.error,
          size: 20,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha:0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Contenuto non consentito',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  'Modifica il testo per poter pubblicare',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer.withValues(alpha:0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return Tooltip(
        message: 'Linguaggio sensibile rilevato',
        child: Icon(
          Icons.warning_amber,
          color: theme.colorScheme.tertiary,
          size: 20,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha:0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: theme.colorScheme.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attenzione: linguaggio sensibile rilevato',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline warning indicator for text fields
class ContentWarningIndicator extends ConsumerWidget {
  const ContentWarningIndicator({
    super.key,
    this.size = 20,
  });

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkState = ref.watch(contentCheckNotifierProvider);
    final theme = Theme.of(context);

    if (checkState.isChecking) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (checkState.isBlocked) {
      return Icon(
        Icons.block,
        color: theme.colorScheme.error,
        size: size,
      );
    }

    if (checkState.hasWarnings) {
      return Icon(
        Icons.warning_amber,
        color: theme.colorScheme.tertiary,
        size: size,
      );
    }

    if (checkState.result != null && checkState.isClean) {
      return Icon(
        Icons.check_circle_outline,
        color: theme.colorScheme.primary.withValues(alpha:0.5),
        size: size,
      );
    }

    return SizedBox(width: size, height: size);
  }
}
