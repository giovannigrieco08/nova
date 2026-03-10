// Screen: ModerationScreen
// Feature: 005-moderation-admin-panel
// Purpose: Queue of pending events and reports for moderators/admins to review

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../../../shared/widgets/nova_toast.dart';
import '../../../events/presentation/providers/events_feed_provider.dart';
import '../../data/models/moderation_event.dart';
import '../../data/models/moderation_report.dart';
import '../providers/pending_events_provider.dart';
import '../providers/pending_reports_provider.dart';

/// Moderation queue screen for admins and moderators
///
/// Shows pending events and reports waiting for approval/rejection.
/// Only accessible to users with 'moderator' or 'admin' roles.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text('Moderazione', style: NovaTypography.headingSmall),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
      );
    }
    return AppBar(
      title: Text(
        'Moderazione',
        style: NovaTypography.headingSmall.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: NovaColors.textPrimary(context),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: NovaColors.surface(context),
      child: TabBar(
        controller: _tabController,
        indicatorColor: NovaColors.primary(context),
        labelColor: NovaColors.primary(context),
        unselectedLabelColor: NovaColors.textSecondary(context),
        tabs: const [
          Tab(text: 'Eventi'),
          Tab(text: 'Segnalazioni'),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final pendingEventsAsync = ref.watch(pendingEventsProvider);

    return pendingEventsAsync.when(
      data: (events) => _buildEventsList(events),
      loading: () => const Center(child: AdaptiveLoadingIndicator()),
      error: (error, _) => _buildErrorView(error, isEvents: true),
    );
  }

  Widget _buildReportsTab() {
    final pendingReportsAsync = ref.watch(pendingReportsProvider);

    return pendingReportsAsync.when(
      data: (reports) => _buildReportsList(reports),
      loading: () => const Center(child: AdaptiveLoadingIndicator()),
      error: (error, _) => _buildErrorView(error, isEvents: false),
    );
  }

  Widget _buildEventsList(List<ModerationEvent> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: NovaColors.success(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Nessun evento in attesa',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              'La coda di moderazione è vuota',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingEventsProvider);
      },
      child: ListView.separated(
        padding: EdgeInsets.all(NovaSpacing.medium),
        itemCount: events.length,
        separatorBuilder: (_, __) => SizedBox(height: NovaSpacing.medium),
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildReportsList(List<ModerationReport> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: NovaColors.success(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Nessuna segnalazione in attesa',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              'La coda delle segnalazioni è vuota',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingReportsProvider);
      },
      child: ListView.separated(
        padding: EdgeInsets.all(NovaSpacing.medium),
        itemCount: reports.length,
        separatorBuilder: (_, __) => SizedBox(height: NovaSpacing.medium),
        itemBuilder: (context, index) {
          final report = reports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(ModerationReport report) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.large),
        border: Border.all(
          color: report.isUrgent
              ? NovaColors.error(context)
              : NovaColors.border(context),
          width: report.isUrgent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reported user info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: NovaColors.backgroundSecondary(context),
                  backgroundImage: report.reportedUserAvatarUrl != null
                      ? NetworkImage(report.reportedUserAvatarUrl!)
                      : null,
                  child: report.reportedUserAvatarUrl == null
                      ? Icon(
                          Icons.person,
                          color: NovaColors.textSecondary(context),
                        )
                      : null,
                ),
                SizedBox(width: NovaSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.reportedUserDisplayName,
                        style: NovaTypography.labelLarge.copyWith(
                          color: NovaColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${report.contentTypeDisplayName} segnalato • ${report.timeSinceSubmission}',
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Urgent badge
                if (report.isUrgent)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: NovaSpacing.small,
                      vertical: NovaSpacing.xsmall,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.error(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(NovaRadius.small),
                    ),
                    child: Text(
                      'Urgente',
                      style: NovaTypography.labelSmall.copyWith(
                        color: NovaColors.error(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Report category and note
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 16,
                      color: NovaColors.error(context),
                    ),
                    SizedBox(width: NovaSpacing.xsmall),
                    Text(
                      report.category.displayName,
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.error(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (report.note != null && report.note!.isNotEmpty) ...[
                  SizedBox(height: NovaSpacing.small),
                  Text(
                    report.note!,
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textPrimary(context),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Reporter info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.xsmall),
                Text(
                  'Segnalato da: ${report.reporterName ?? report.reporterUsername ?? 'Utente'}',
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: NovaColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                // Dismiss button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _dismissReport(report),
                    icon: Icon(
                      Icons.close,
                      color: NovaColors.textSecondary(context),
                    ),
                    label: Text(
                      'Archivia',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: NovaColors.border(context),
                ),
                // Remove content button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _removeContent(report),
                    icon: Icon(
                      Icons.delete_outline,
                      color: NovaColors.warning(context),
                    ),
                    label: Text(
                      'Rimuovi',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.warning(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: NovaColors.border(context),
                ),
                // Ban user button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showBanDialog(report),
                    icon: Icon(
                      Icons.block,
                      color: NovaColors.error(context),
                    ),
                    label: Text(
                      'Banna',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.error(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(ModerationEvent event) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.large),
        border: Border.all(color: NovaColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with organizer info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                // Emoji/cover indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: NovaColors.backgroundSecondary(context),
                    borderRadius: BorderRadius.circular(NovaRadius.medium),
                  ),
                  child: Center(
                    child: event.coverImageUrl != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(NovaRadius.medium),
                            child: Image.network(
                              event.coverImageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            event.emojiIcon ?? '',
                            style: const TextStyle(fontSize: 22),
                          ),
                  ),
                ),
                SizedBox(width: NovaSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: NovaTypography.labelLarge.copyWith(
                          color: NovaColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'di ${event.organizerName ?? 'Utente'} • ${event.timeSinceSubmission}',
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Resubmission badge
                if (event.isResubmission)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: NovaSpacing.small,
                      vertical: NovaSpacing.xsmall,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.warning(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(NovaRadius.small),
                    ),
                    child: Text(
                      'Re-invio',
                      style: NovaTypography.labelSmall.copyWith(
                        color: NovaColors.warning(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Description preview
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
            child: Text(
              event.descriptionPreview,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Date and location info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.xsmall),
                Expanded(
                  child: Text(
                    event.formattedDateRange,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ),
                if (event.location != null) ...[
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: NovaColors.textSecondary(context),
                  ),
                  SizedBox(width: NovaSpacing.xsmall),
                  Text(
                    event.location!,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: NovaColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                // Reject button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRejectDialog(event),
                    icon: Icon(
                      Icons.close,
                      color: NovaColors.error(context),
                    ),
                    label: Text(
                      'Rifiuta',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.error(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: NovaColors.border(context),
                ),
                // Approve button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _approveEvent(event),
                    icon: Icon(
                      Icons.check,
                      color: NovaColors.success(context),
                    ),
                    label: Text(
                      'Approva',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.success(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _dismissReport(ModerationReport report) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('review_report', params: {
        'p_report_id': report.id,
        'p_action': 'dismissed',
      });

      ref.invalidate(pendingReportsProvider);

      if (mounted) {
        NovaToast.showSuccess(context, 'Segnalazione archiviata');
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: $e');
      }
    }
  }

  Future<void> _removeContent(ModerationReport report) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('review_report', params: {
        'p_report_id': report.id,
        'p_action': 'content_removed',
      });

      ref.invalidate(pendingReportsProvider);

      if (mounted) {
        NovaToast.showSuccess(context, 'Contenuto rimosso');
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: $e');
      }
    }
  }

  Future<void> _showBanDialog(ModerationReport report) async {
    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Banna utente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stai per bannare: ${report.reportedUserDisplayName}',
              style: NovaTypography.bodyMedium,
            ),
            SizedBox(height: NovaSpacing.medium),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Motivo del ban...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'reason': reasonController.text.trim(),
                });
              }
            },
            child: Text(
              'Banna',
              style: TextStyle(color: NovaColors.error(context)),
            ),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (result != null) {
      await _banUser(report, result['reason'] as String);
    }
  }

  Future<void> _banUser(ModerationReport report, String reason) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('review_report', params: {
        'p_report_id': report.id,
        'p_action': 'user_banned',
        'p_sanction_reason': reason,
      });

      ref.invalidate(pendingReportsProvider);

      if (mounted) {
        NovaToast.showSuccess(
            context, 'Utente ${report.reportedUserDisplayName} bannato');
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: $e');
      }
    }
  }

  Future<void> _approveEvent(ModerationEvent event) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('moderate_event', params: {
        'p_event_id': event.id,
        'p_action': 'approved',
      });

      // Force refresh to update UI immediately
      ref.invalidate(pendingEventsProvider);
      // Also refresh the events feed so the approved event appears there
      ref.read(eventsFeedProvider.notifier).refresh();

      if (mounted) {
        NovaToast.showSuccess(context, 'Evento "${event.title}" approvato');
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: $e');
      }
    }
  }

  Future<void> _showRejectDialog(ModerationEvent event) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo del rifiuto'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Inserisci il motivo...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: Text(
              'Rifiuta',
              style: TextStyle(color: NovaColors.error(context)),
            ),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason != null && reason.isNotEmpty) {
      await _rejectEvent(event, reason);
    }
  }

  Future<void> _rejectEvent(ModerationEvent event, String reason) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('moderate_event', params: {
        'p_event_id': event.id,
        'p_action': 'rejected',
        'p_rejection_reason': reason,
      });

      // Force refresh to update UI immediately
      ref.invalidate(pendingEventsProvider);

      if (mounted) {
        NovaToast.showSuccess(context, 'Evento "${event.title}" rifiutato');
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore: $e');
      }
    }
  }

  Widget _buildErrorView(Object error, {required bool isEvents}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Errore nel caricamento',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              error.toString(),
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.large),
            ElevatedButton(
              onPressed: () {
                if (isEvents) {
                  ref.invalidate(pendingEventsProvider);
                } else {
                  ref.invalidate(pendingReportsProvider);
                }
              },
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
