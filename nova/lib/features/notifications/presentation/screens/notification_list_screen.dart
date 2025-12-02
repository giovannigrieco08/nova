import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/notification.dart' as domain;
import '../providers/notification_providers.dart';
import '../widgets/notification_tile.dart';

/// Notification list screen
///
/// Displays all notifications for the current user with:
/// - Pull-to-refresh
/// - Swipe-to-delete individual notifications
/// - Mark all as read action
/// - Empty state when no notifications
/// - Navigate to notification settings
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationNotifierProvider);

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        title: Text(
          'Notifiche',
          style: NovaTextStyles.h2.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        actions: [
          // Mark all as read
          if (notificationState.notifications.any((n) => n.isUnread))
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: NovaColors.primary(context),
              ),
              tooltip: 'Segna tutte come lette',
              onPressed: () => _markAllAsRead(context, ref),
            ),
          // Settings
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: NovaColors.textSecondary(context),
            ),
            tooltip: 'Impostazioni notifiche',
            onPressed: () => context.push('/notifications/settings'),
          ),
        ],
      ),
      body: _buildBody(context, ref, notificationState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationState state,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null) {
      return _buildErrorState(context, ref, state.error!);
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationNotifierProvider.notifier).refresh(),
      color: NovaColors.primary(context),
      child: ListView.builder(
        itemCount: state.notifications.length,
        itemBuilder: (context, index) {
          final notification = state.notifications[index];
          return NotificationTile(
            notification: notification,
            onTap: () => _navigateToTarget(context, notification),
            onDelete: () => _deleteNotification(context, ref, notification.id),
            onMarkAsRead: () => _markAsRead(ref, notification.id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: NovaColors.textTertiary(context),
            ),
            SizedBox(height: NovaSpacing.l),
            Text(
              'Nessuna notifica',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              'Le tue notifiche appariranno qui',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.l),
            Text(
              'Errore nel caricamento',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              error,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () =>
                  ref.read(notificationNotifierProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
              ),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to notification target (event or comment)
  void _navigateToTarget(BuildContext context, domain.Notification notification) {
    if (notification.targetType == 'event') {
      context.push('/events/${notification.targetId}');
    } else if (notification.targetType == 'comment') {
      // Navigate to event with comment ID in metadata
      final eventId = notification.metadata['event_id'] as String?;
      if (eventId != null) {
        context.push('/events/$eventId?commentId=${notification.targetId}');
      }
    }
  }

  /// Mark single notification as read
  void _markAsRead(WidgetRef ref, String notificationId) {
    ref.read(notificationNotifierProvider.notifier).markAsRead(notificationId);
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationNotifierProvider.notifier).markAllAsRead();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tutte le notifiche segnate come lette'),
            backgroundColor: NovaColors.success(context),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  /// Delete notification
  void _deleteNotification(
    BuildContext context,
    WidgetRef ref,
    String notificationId,
  ) {
    ref
        .read(notificationNotifierProvider.notifier)
        .deleteNotification(notificationId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifica eliminata'),
        backgroundColor: NovaColors.textSecondary(context),
        action: SnackBarAction(
          label: 'Annulla',
          textColor: NovaColors.primary(context),
          onPressed: () {
            // TODO: Implement undo (requires keeping deleted notification in memory)
            ref.read(notificationNotifierProvider.notifier).refresh();
          },
        ),
      ),
    );
  }
}
