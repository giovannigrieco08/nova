// Screen: OtherProfileScreen
// Feature: 006-user-profile (User Story 2 - T049)
// Purpose: View other users' profiles (read-only, privacy-enforced)

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../providers/other_profile_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart' as widgets;
import '../widgets/profile_tabs.dart';
import '../widgets/events_grid.dart';
import '../widgets/share_profile_sheet.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_button.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
// Tutoring feature imports (T045-T048)
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/widgets/tutor_profile_section.dart';

/// Screen for viewing other users' profiles
///
/// **Features**:
/// - Profile header (avatar, name, username, class, bio, moderator badge)
/// - Profile stats (eventi creati only - no participations for privacy)
/// - Only "Eventi" tab visible (no "Partecipazioni" tab for privacy)
/// - "Condividi Profilo" button (placeholder for US4 - deep link sharing)
/// - NO "Modifica Profilo" button (read-only view)
///
/// **Privacy Enforcement**:
/// - RLS policies ensure only public profiles visible (profile_visible=true AND deleted_at IS NULL)
/// - If profile is hidden/deleted, shows "Profilo non disponibile" error state
/// - Only shows user's created events (no participation history)
///
/// **Design**:
/// - Scrollable: CustomScrollView with SliverAppBar (iOS) or AppBar (Android)
/// - Pull-to-refresh: Refresh profile data
/// - Loading state: Shimmer placeholders or CircularProgressIndicator
/// - Error state: "Profilo non disponibile" with back button
///
/// **Usage**:
/// ```dart
/// // Navigate from EventCard creator tap or deep link
/// Navigator.push(
///   context,
///   Platform.isIOS
///     ? CupertinoPageRoute(builder: (_) => OtherProfileScreen(userId: 'uuid-here'))
///     : MaterialPageRoute(builder: (_) => OtherProfileScreen(userId: 'uuid-here')),
/// )
/// ```
class OtherProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherProfileScreen({
    required this.userId,
    super.key,
  });

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(otherProfileProvider(widget.userId));
    final statsAsync = ref.watch(otherProfileStatsProvider(widget.userId));

    return profileAsync.when(
      data: (profile) => _buildProfileView(profile, statsAsync),
      loading: () => _buildLoadingView(),
      error: (error, stack) => _buildErrorView(error),
    );
  }

  /// Build profile view with data
  Widget _buildProfileView(Profile? profile, AsyncValue<ProfileStats?> statsAsync) {
    if (profile == null) {
      return _buildErrorView(Exception('Profile not found'));
    }
    return AdaptiveScaffold(
      appBar: _buildAppBar(profile),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh profile and stats
          ref.invalidate(otherProfileProvider(widget.userId));
          ref.invalidate(otherProfileStatsProvider(widget.userId));
        },
        child: CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: ProfileHeader(
                profile: profile,
                isOwnProfile: false, // Read-only view
              ),
            ),

            // Profile stats
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => stats != null
                    ? widgets.UserProfileStats(stats: stats)
                    : const SizedBox.shrink(),
                loading: () => Padding(
                  padding: EdgeInsets.all(NovaSpacing.medium),
                  child: const AdaptiveLoadingIndicator(),
                ),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ),

            // Tutor profile section (T045-T048: FR-020)
            SliverToBoxAdapter(
              child: _buildTutorSection(profile),
            ),

            // "Condividi Profilo" button (placeholder for US4)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: NovaSpacing.large),
                child: AdaptiveButton(
                  type: AdaptiveButtonType.secondary,
                  onPressed: () => _shareProfile(profile),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Platform.isIOS ? CupertinoIcons.share : Icons.share_rounded,
                        size: 18,
                        color: NovaColors.textPrimary(context),
                      ),
                      SizedBox(width: NovaSpacing.small),
                      Text(
                        'Condividi Profilo',
                        style: NovaTypography.bodyMedium.copyWith(
                          color: NovaColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: NovaSpacing.medium).toSliver(),

            // Only "Eventi" tab (NO Partecipazioni for privacy)
            SliverToBoxAdapter(
              child: ProfileTabs(
                selectedTab: ProfileTab.eventi,
                onTabChanged: (_) {}, // No-op since only one tab
                showPartecipazioni: false, // Privacy: only show created events
              ),
            ),

            // Events grid (created events only)
            SliverFillRemaining(
              child: _buildEventsGrid(profile, statsAsync),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar with profile name
  PreferredSizeWidget _buildAppBar(Profile profile) {
    final displayName = profile.fullName.isNotEmpty ? profile.fullName : profile.username;

    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text(
          displayName,
          style: NovaTypography.headingMedium,
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: 'Indietro',
      );
    } else {
      return AppBar(
        title: Text(
          displayName,
          style: NovaTypography.headingMedium,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }

  /// Build events grid (created events only)
  Widget _buildEventsGrid(Profile profile, AsyncValue<ProfileStats?> statsAsync) {
    // TODO(T037): Replace with actual event queries
    // For now, show placeholder empty state

    return EventsGrid(
      events: const [], // TODO: Load created events for this user
      onEventTap: _navigateToEventDetail,
      emptyMessage: 'Nessun evento creato.',
    );
  }

  /// Share profile (T075 - show ShareProfileSheet)
  void _shareProfile(Profile profile) {
    ShareProfileSheet.show(context, profile);
  }

  /// Navigate to event detail
  void _navigateToEventDetail(dynamic event) {
    // TODO: Navigate to EventDetailScreen
  }

  /// Build tutor section for other user's profile (T045-T048)
  ///
  /// Shows TutorProfileSection with isOwnProfile: false (T046)
  /// The "Contatta per Ripetizioni" button and ContactTutorSheet are
  /// handled inside TutorProfileSection (T047, T048)
  Widget _buildTutorSection(Profile profile) {
    final tutorAsync = ref.watch(otherTutorProfileProvider(widget.userId));

    return tutorAsync.when(
      data: (tutorProfile) {
        if (tutorProfile == null) {
          // User is not a tutor - show nothing
          return const SizedBox.shrink();
        }
        // Show tutor profile section with contact button
        return TutorProfileSection(
          profile: tutorProfile,
          isOwnProfile: false, // T046: External profile view
          authorName: profile.fullName.isNotEmpty ? profile.fullName : profile.username, // For ContactTutorSheet
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Show toast message
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NovaColors.backgroundSecondary(context),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Profilo'),
          previousPageTitle: 'Indietro',
        ),
        child: const Center(
          child: AdaptiveLoadingIndicator(),
        ),
      );
    }
    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
      ),
      body: const Center(
        child: AdaptiveLoadingIndicator(),
      ),
    );
  }

  /// Build error view ("Profilo non disponibile")
  Widget _buildErrorView(Object error) {
    // Check if error is privacy-related (profile hidden or deleted)
    final isPrivacyError = error.toString().contains('No rows') ||
        error.toString().contains('not found') ||
        error.toString().contains('visible');

    final errorTitle = isPrivacyError
        ? 'Profilo non disponibile'
        : 'Errore nel caricare il profilo';

    final errorMessage = isPrivacyError
        ? 'Questo profilo è privato o è stato eliminato.'
        : error.toString();

    final errorBody = Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPrivacyError
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              size: 64,
              color: isPrivacyError ? NovaColors.textTertiary(context) : NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              errorTitle,
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              errorMessage,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.large),
            if (!isPrivacyError)
              AdaptiveButton(
                type: AdaptiveButtonType.primary,
                onPressed: () {
                  ref.invalidate(otherProfileProvider(widget.userId));
                },
                child: Text(
                  'Riprova',
                  style: NovaTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isPrivacyError)
              AdaptiveButton(
                type: AdaptiveButtonType.secondary,
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Torna indietro',
                  style: NovaTypography.bodyMedium.copyWith(
                    color: NovaColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Profilo'),
          previousPageTitle: 'Indietro',
        ),
        child: errorBody,
      );
    }
    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
      ),
      body: errorBody,
    );
  }
}

/// Extension to convert SizedBox to SliverToBoxAdapter
extension SizedBoxSliver on SizedBox {
  SliverToBoxAdapter toSliver() => SliverToBoxAdapter(child: this);
}
