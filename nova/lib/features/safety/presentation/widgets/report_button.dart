import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/report.dart';
import '../providers/report_provider.dart';
import 'report_sheet.dart';

/// A button widget for reporting content
///
/// Shows appropriate state based on whether content has been reported
class ReportButton extends ConsumerWidget {
  const ReportButton({
    super.key,
    required this.contentType,
    required this.contentId,
    this.onReported,
    this.iconOnly = false,
  });

  final ReportableContentType contentType;
  final String contentId;
  final VoidCallback? onReported;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReported = ref.watch(
      hasReportedProvider((contentType: contentType, contentId: contentId)),
    );

    return hasReported.when(
      data: (reported) => reported
          ? _buildReportedState(context)
          : _buildReportButton(context),
      loading: () => _buildLoadingState(context),
      error: (_, __) => _buildReportButton(context),
    );
  }

  Widget _buildReportButton(BuildContext context) {
    final theme = Theme.of(context);

    if (iconOnly) {
      return IconButton(
        icon: const Icon(Icons.flag_outlined),
        onPressed: () => _showReportSheet(context),
        tooltip: 'Segnala',
      );
    }

    return TextButton.icon(
      onPressed: () => _showReportSheet(context),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Segnala'),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }

  Widget _buildReportedState(BuildContext context) {
    final theme = Theme.of(context);

    if (iconOnly) {
      return IconButton(
        icon: Icon(
          Icons.flag,
          color: theme.colorScheme.error.withOpacity(0.5),
        ),
        onPressed: null,
        tooltip: 'Già segnalato',
      );
    }

    return TextButton.icon(
      onPressed: null,
      icon: Icon(
        Icons.flag,
        size: 18,
        color: theme.colorScheme.error.withOpacity(0.5),
      ),
      label: Text(
        'Già segnalato',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    if (iconOnly) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: null,
      icon: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: const Text('...'),
    );
  }

  void _showReportSheet(BuildContext context) {
    ReportCategorySheet.show(
      context,
      contentType: contentType,
      contentId: contentId,
      onReportSubmitted: onReported,
    );
  }
}

/// A menu item for use in popup menus and overflow menus
class ReportMenuItem extends ConsumerWidget {
  const ReportMenuItem({
    super.key,
    required this.contentType,
    required this.contentId,
    this.onReported,
  });

  final ReportableContentType contentType;
  final String contentId;
  final VoidCallback? onReported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReported = ref.watch(
      hasReportedProvider((contentType: contentType, contentId: contentId)),
    );

    final isReported = hasReported.valueOrNull ?? false;
    final isLoading = hasReported.isLoading;

    return PopupMenuItem<void>(
      enabled: !isReported && !isLoading,
      onTap: () {
        // Delay to allow popup to close
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            ReportCategorySheet.show(
              context,
              contentType: contentType,
              contentId: contentId,
              onReportSubmitted: onReported,
            );
          }
        });
      },
      child: Row(
        children: [
          Icon(
            isReported ? Icons.flag : Icons.flag_outlined,
            color: isReported
                ? Theme.of(context).colorScheme.error.withOpacity(0.5)
                : null,
          ),
          const SizedBox(width: 12),
          Text(isReported ? 'Già segnalato' : 'Segnala'),
        ],
      ),
    );
  }
}

/// ListTile for use in bottom sheets and action sheets
class ReportListTile extends ConsumerWidget {
  const ReportListTile({
    super.key,
    required this.contentType,
    required this.contentId,
    this.onReported,
  });

  final ReportableContentType contentType;
  final String contentId;
  final VoidCallback? onReported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReported = ref.watch(
      hasReportedProvider((contentType: contentType, contentId: contentId)),
    );

    final isReported = hasReported.valueOrNull ?? false;
    final isLoading = hasReported.isLoading;
    final theme = Theme.of(context);

    return ListTile(
      enabled: !isReported && !isLoading,
      leading: Icon(
        isReported ? Icons.flag : Icons.flag_outlined,
        color: isReported
            ? theme.colorScheme.error.withOpacity(0.5)
            : theme.colorScheme.error,
      ),
      title: Text(
        isReported ? 'Già segnalato' : 'Segnala',
        style: TextStyle(
          color: isReported
              ? theme.colorScheme.onSurface.withOpacity(0.5)
              : theme.colorScheme.error,
        ),
      ),
      subtitle: isReported
          ? null
          : Text(
              'Segnala contenuto inappropriato',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
      onTap: isReported || isLoading
          ? null
          : () {
              Navigator.of(context).pop(); // Close the action sheet
              ReportCategorySheet.show(
                context,
                contentType: contentType,
                contentId: contentId,
                onReportSubmitted: onReported,
              );
            },
    );
  }
}
