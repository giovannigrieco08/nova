// =====================================================================
// AdminPanelScreen - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Main admin panel screen for moderator management
// Architecture: Scaffold with 3 sections (search, list, stats)
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_app_bar.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_scaffold.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_loading_indicator.dart';
import 'package:nova/features/admin/presentation/providers/moderators_provider.dart';
import 'package:nova/features/admin/presentation/providers/system_stats_provider.dart';
import 'package:nova/features/admin/presentation/widgets/moderator_search.dart';
import 'package:nova/features/admin/presentation/widgets/moderator_card.dart';
import 'package:nova/features/admin/presentation/widgets/system_statistics_widget.dart';
import 'package:nova/features/admin/presentation/widgets/activity_log_widget.dart';

/// Admin panel screen
///
/// Allows admin to:
/// 1. Search and promote users to moderator
/// 2. View all moderators with statistics
/// 3. Remove moderator roles
/// 4. View system-wide statistics
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderatorsAsync = ref.watch(moderatorsProvider);
    final systemStatsAsync = ref.watch(systemStatsProvider);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh both providers
              ref.invalidate(moderatorsProvider);
              ref.invalidate(systemStatsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moderatorsProvider);
          ref.invalidate(systemStatsProvider);
          // Wait for providers to refresh
          await Future.wait([
            ref.read(moderatorsProvider.future),
            ref.read(systemStatsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(NovaSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Search for users to promote
              Text(
                'Cerca studente',
                style: NovaTextStyles.h2,
              ),
              const SizedBox(height: NovaSpacing.m),
              const ModeratorSearch(),

              const SizedBox(height: NovaSpacing.xl),

              // Section 2: Current moderators list
              Text(
                'Moderatori attuali',
                style: NovaTextStyles.h2,
              ),
              const SizedBox(height: NovaSpacing.m),
              moderatorsAsync.when(
                data: (moderators) {
                  if (moderators.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(NovaSpacing.xl),
                      decoration: BoxDecoration(
                        color: NovaColors.surface(context),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: NovaColors.textTertiary(context),
                            ),
                            const SizedBox(height: NovaSpacing.m),
                            Text(
                              'Nessun moderatore',
                              style: NovaTextStyles.body.copyWith(
                                color: NovaColors.textTertiary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: moderators.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: NovaSpacing.m),
                    itemBuilder: (context, index) {
                      return ModeratorCard(moderator: moderators[index]);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(NovaSpacing.xl),
                    child: AdaptiveLoadingIndicator(),
                  ),
                ),
                error: (error, _) => Container(
                  padding: const EdgeInsets.all(NovaSpacing.m),
                  decoration: BoxDecoration(
                    color: NovaColors.error(context).withOpacity(0.1),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Errore caricamento moderatori: $error',
                    style: NovaTextStyles.body.copyWith(
                      color: NovaColors.error(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: NovaSpacing.xl),

              // Section 3: System statistics
              Text(
                'Statistiche sistema',
                style: NovaTextStyles.h2,
              ),
              const SizedBox(height: NovaSpacing.m),
              systemStatsAsync.when(
                data: (stats) => SystemStatisticsWidget(stats: stats),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(NovaSpacing.xl),
                    child: AdaptiveLoadingIndicator(),
                  ),
                ),
                error: (error, _) => Container(
                  padding: const EdgeInsets.all(NovaSpacing.m),
                  decoration: BoxDecoration(
                    color: NovaColors.error(context).withOpacity(0.1),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Errore caricamento statistiche: $error',
                    style: NovaTextStyles.body.copyWith(
                      color: NovaColors.error(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: NovaSpacing.xl),

              // Section 4: Activity Log
              Text(
                'Registro attività',
                style: NovaTextStyles.h2,
              ),
              const SizedBox(height: NovaSpacing.m),
              const ActivityLogWidget(),

              // Bottom padding for scroll
              const SizedBox(height: NovaSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
