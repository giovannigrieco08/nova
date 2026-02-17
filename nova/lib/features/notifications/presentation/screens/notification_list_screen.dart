import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_channel.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_tile.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../events/presentation/providers/events_feed_provider.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';

/// Notification list screen (Instagram-style)
///
/// Features:
/// - Time-based grouping: "Oggi", "Ieri", "Ultimi 7 giorni"
/// - Pull-to-refresh
/// - Swipe-to-delete individual notifications
/// - Clean minimal AppBar with chevron back button
/// - Empty state when no notifications
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationNotifierProvider);

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: NovaColors.textPrimary(context),
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifiche',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        centerTitle: false,
        backgroundColor: NovaColors.background(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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

    // Group notifications by date
    final grouped = _groupByDate(state.notifications);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationNotifierProvider.notifier).refresh(),
      color: NovaColors.primary(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Oggi
          if (grouped['oggi']!.isNotEmpty) ...[
            _buildSectionHeader(context, 'Oggi'),
            ...grouped['oggi']!.map((notification) => NotificationTile(
                  notification: notification,
                  onTap: () => _navigateToTarget(context, notification),
                  onDelete: () =>
                      _deleteNotification(context, ref, notification.id),
                  onMarkAsRead: () => _markAsRead(ref, notification.id),
                  onAccept: () => _handleInvitationResponse(
                      context, ref, notification, true),
                  onReject: () => _handleInvitationResponse(
                      context, ref, notification, false),
                )),
          ],

          // Ieri
          if (grouped['ieri']!.isNotEmpty) ...[
            _buildSectionHeader(context, 'Ieri'),
            ...grouped['ieri']!.map((notification) => NotificationTile(
                  notification: notification,
                  onTap: () => _navigateToTarget(context, notification),
                  onDelete: () =>
                      _deleteNotification(context, ref, notification.id),
                  onMarkAsRead: () => _markAsRead(ref, notification.id),
                  onAccept: () => _handleInvitationResponse(
                      context, ref, notification, true),
                  onReject: () => _handleInvitationResponse(
                      context, ref, notification, false),
                )),
          ],

          // Ultimi 7 giorni
          if (grouped['settimana']!.isNotEmpty) ...[
            _buildSectionHeader(context, 'Ultimi 7 giorni'),
            ...grouped['settimana']!.map((notification) => NotificationTile(
                  notification: notification,
                  onTap: () => _navigateToTarget(context, notification),
                  onDelete: () =>
                      _deleteNotification(context, ref, notification.id),
                  onMarkAsRead: () => _markAsRead(ref, notification.id),
                  onAccept: () => _handleInvitationResponse(
                      context, ref, notification, true),
                  onReject: () => _handleInvitationResponse(
                      context, ref, notification, false),
                )),
          ],

          // Precedenti (older than 7 days)
          if (grouped['precedenti']!.isNotEmpty) ...[
            _buildSectionHeader(context, 'Precedenti'),
            ...grouped['precedenti']!.map((notification) => NotificationTile(
                  notification: notification,
                  onTap: () => _navigateToTarget(context, notification),
                  onDelete: () =>
                      _deleteNotification(context, ref, notification.id),
                  onMarkAsRead: () => _markAsRead(ref, notification.id),
                  onAccept: () => _handleInvitationResponse(
                      context, ref, notification, true),
                  onReject: () => _handleInvitationResponse(
                      context, ref, notification, false),
                )),
          ],

          // Bottom padding
          SizedBox(height: NovaSpacing.xl),
        ],
      ),
    );
  }

  /// Group notifications by date
  Map<String, List<AppNotification>> _groupByDate(
      List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final oggi = <AppNotification>[];
    final ieri = <AppNotification>[];
    final settimana = <AppNotification>[];
    final precedenti = <AppNotification>[];

    for (final notification in notifications) {
      final notifDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (notifDate.isAtSameMomentAs(today) || notifDate.isAfter(today)) {
        oggi.add(notification);
      } else if (notifDate.isAtSameMomentAs(yesterday)) {
        ieri.add(notification);
      } else if (notifDate.isAfter(weekAgo)) {
        settimana.add(notification);
      } else {
        precedenti.add(notification);
      }
    }

    return {
      'oggi': oggi,
      'ieri': ieri,
      'settimana': settimana,
      'precedenti': precedenti,
    };
  }

  /// Build section header (Instagram-style)
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: EdgeInsets.only(
        left: NovaSpacing.l,
        right: NovaSpacing.l,
        top: NovaSpacing.l,
        bottom: NovaSpacing.s,
      ),
      child: Text(
        title,
        style: NovaTypography.sectionTitle.copyWith(
          color: NovaColors.textPrimary(context),
        ),
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
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              'Le tue notifiche appariranno qui',
              style: NovaTypography.bodyMedium.copyWith(
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
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              error,
              style: NovaTypography.bodyMedium.copyWith(
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

  /// Navigate to notification target (event, comment, chat, or profile)
  void _navigateToTarget(BuildContext context, AppNotification notification) {
    // Handle chat mentions specially (navigate to chat screen)
    if (notification.channel == NotificationChannel.chatMention) {
      Navigator.push(
        context,
        NovaPageRoute.swipeBack(page: const ChatScreen()),
      );
      return;
    }

    // Navigate based on notification data
    final data = notification.data;
    if (data != null) {
      final targetType = data['target_type'] as String?;
      final targetId = data['target_id'] as String?;

      if (targetType == 'event' && targetId != null) {
        Navigator.push(
          context,
          NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: targetId)),
        );
      } else if (targetType == 'comment' && targetId != null) {
        // Navigate to event (comments are on event screen)
        final eventId = data['event_id'] as String?;
        if (eventId != null) {
          Navigator.push(
            context,
            NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: eventId)),
          );
        }
      } else if (targetType == 'chat' || targetType == 'chat_mention') {
        // Navigate to chat screen
        Navigator.push(
          context,
          NovaPageRoute.swipeBack(page: const ChatScreen()),
        );
      } else if (targetType == 'profile' && targetId != null) {
        // Navigate to profile
        Navigator.push(
          context,
          NovaPageRoute.swipeBack(page: OtherProfileScreen(userId: targetId)),
        );
      }
    }
  }

  /// Mark single notification as read
  void _markAsRead(WidgetRef ref, String notificationId) {
    ref.read(notificationNotifierProvider.notifier).markAsRead(notificationId);
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
            ref.read(notificationNotifierProvider.notifier).refresh();
          },
        ),
      ),
    );
  }

  /// Handle invitation accept/reject
  Future<void> _handleInvitationResponse(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    bool accept,
  ) async {
    // Get invitation_id from notification metadata
    final invitationId = notification.data?['invitation_id'] as String?;
    if (invitationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Errore: invito non trovato'),
          backgroundColor: NovaColors.error(context),
        ),
      );
      return;
    }

    try {
      final repository = ref.read(eventsRepositoryProvider);
      await repository.respondToInvitation(
        invitationId: invitationId,
        status: accept ? 'accepted' : 'declined',
      );

      // Mark notification as read and delete it
      ref
          .read(notificationNotifierProvider.notifier)
          .markAsRead(notification.id);
      ref
          .read(notificationNotifierProvider.notifier)
          .deleteNotification(notification.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? 'Invito accettato! Ora sei co-organizzatore'
                : 'Invito rifiutato'),
            backgroundColor:
                accept ? Colors.green : NovaColors.textSecondary(context),
          ),
        );

        // If accepted, navigate to the event
        if (accept) {
          final targetId = notification.data?['target_id'] as String?;
          if (targetId != null) {
            Navigator.push(
              context,
              NovaPageRoute.swipeBack(
                  page: EventDetailScreen(eventId: targetId)),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }
}
