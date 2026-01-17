// Screen: ProfileScreen
// Feature: 006-user-profile (User Story 1 - T039)
// Purpose: Own profile view with header, stats, tabs, edit button, settings icon

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_tabs.dart';
import '../widgets/events_grid.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'profile_photo_viewer_screen.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_button.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
// Tutoring feature imports
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/widgets/become_tutor_card.dart';
import '../../../tutoring/presentation/widgets/tutor_profile_section.dart';
import '../../../tutoring/presentation/screens/become_tutor_screen.dart';
// Events imports
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
// Moderation imports
import '../../../moderation/presentation/screens/moderation_screen.dart';
import '../../../moderation/presentation/providers/pending_count_provider.dart';

/// Profile screen for viewing own profile
///
/// **Features**:
/// - Profile header (avatar, name, username, class, bio, moderator badge)
/// - Profile stats (eventi creati, partecipazioni)
/// - Tabs: Eventi / Partecipazioni (platform-adaptive)
/// - "Modifica Profilo" button → navigate to EditProfileScreen
/// - Settings icon (⚙️) → navigate to SettingsScreen (User Story 3)
///
/// **Design**:
/// - Scrollable: CustomScrollView with SliverAppBar (iOS) or AppBar (Android)
/// - Pull-to-refresh: Refresh profile data
/// - Loading state: Shimmer placeholders or CircularProgressIndicator
/// - Error state: Error message with retry button
///
/// **Usage**:
/// ```dart
/// // Navigate to ProfileScreen
/// Navigator.push(
///   context,
///   Platform.isIOS
///     ? CupertinoPageRoute(builder: (_) => ProfileScreen())
///     : MaterialPageRoute(builder: (_) => ProfileScreen()),
/// )
/// ```
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileTab _selectedTab = ProfileTab.eventi;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(currentProfileStatsProvider);

    return profileAsync.when(
      data: (profile) => _buildProfileView(profile, statsAsync),
      loading: () => _buildLoadingView(),
      error: (error, stack) => _buildErrorView(error),
    );
  }

  /// Build profile view with data
  Widget _buildProfileView(Profile profile, AsyncValue<ProfileStats> statsAsync) {
    final stats = statsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: () async {
          // Refresh profile, stats, and events
          ref.invalidate(currentProfileProvider);
          ref.invalidate(currentProfileStatsProvider);
          ref.invalidate(userCreatedEventsProvider);
          ref.invalidate(userParticipatingEventsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Custom app bar matching MainFeedScreen style
            SliverToBoxAdapter(
              child: _buildCustomAppBar(profile),
            ),

            // Profile header with integrated stats (Instagram-style)
            SliverToBoxAdapter(
              child: ProfileHeader(
                profile: profile,
                stats: stats,
                isOwnProfile: true,
                onAvatarTap: () => _navigateToPhotoViewer(profile),
                onEventiTap: () => setState(() => _selectedTab = ProfileTab.eventi),
                onPartecipazioniTap: () => setState(() => _selectedTab = ProfileTab.partecipazioni),
              ),
            ),

            // Tutor profile section (T030-T032: FR-019)
            SliverToBoxAdapter(
              child: _buildTutorSection(),
            ),

            // Action buttons row (Edit Profile + Moderation if admin/moderator)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: NovaSpacing.large),
                child: Row(
                  children: [
                    // Edit Profile button
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextButton(
                          onPressed: () => _navigateToEditProfile(profile),
                          style: TextButton.styleFrom(
                            backgroundColor: NovaColors.surface(context),
                            foregroundColor: NovaColors.textPrimary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: NovaRadius.circularFull,
                            ),
                            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
                          ),
                          child: Text(
                            'Modifica profilo',
                            style: NovaTypography.bodyMedium.copyWith(
                              color: NovaColors.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Moderation button (only for moderators/admins)
                    if (profile.isModerator) ...[
                      SizedBox(width: NovaSpacing.small),
                      SizedBox(
                        height: 36,
                        child: _buildModerationButton(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: NovaSpacing.medium).toSliver(),

            // Tabs (Eventi / Partecipazioni)
            SliverToBoxAdapter(
              child: ProfileTabs(
                selectedTab: _selectedTab,
                onTabChanged: (tab) => setState(() => _selectedTab = tab),
                showPartecipazioni: true, // Own profile shows both tabs
              ),
            ),

            // Events grid based on selected tab (no separate scroll)
            SliverToBoxAdapter(
              child: _buildEventsGrid(profile, statsAsync),
            ),

            // Bottom padding to prevent content being covered by navbar
            SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Build custom app bar matching MainFeedScreen style
  Widget _buildCustomAppBar([Profile? profile]) {
    final username = profile?.username ?? 'Profilo';

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sinistra: placeholder per mantenere il titolo centrato
          const SizedBox(width: 24),

          // Centro: Username
          Text(
            username,
            style: NovaTypography.headingMedium.copyWith(
              color: NovaColors.textPrimary(context),
            ),
          ),

          // Destra: Menu icon
          GestureDetector(
            onTap: _navigateToSettings,
            child: Icon(
              Icons.menu_rounded,
              color: NovaColors.textPrimary(context),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// Build events grid based on selected tab
  Widget _buildEventsGrid(Profile profile, AsyncValue<ProfileStats> statsAsync) {
    if (_selectedTab == ProfileTab.eventi) {
      // Load user's created events
      final createdEventsAsync = ref.watch(userCreatedEventsProvider);
      return createdEventsAsync.when(
        data: (events) => EventsGrid(
          events: events,
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Nessun evento creato.\nCrea il tuo primo evento!',
          shrinkWrap: true, // Don't scroll independently
        ),
        loading: () => EventsGrid(
          events: const [],
          onEventTap: _navigateToEventDetail,
          isLoading: true,
          shrinkWrap: true,
        ),
        error: (_, __) => EventsGrid(
          events: const [],
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Errore nel caricamento degli eventi.',
          shrinkWrap: true,
        ),
      );
    } else {
      // Load events user is participating in
      final participatingEventsAsync = ref.watch(userParticipatingEventsProvider);
      return participatingEventsAsync.when(
        data: (events) => EventsGrid(
          events: events,
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Nessuna partecipazione.\nPartecipa al tuo primo evento!',
          shrinkWrap: true, // Don't scroll independently
        ),
        loading: () => EventsGrid(
          events: const [],
          onEventTap: _navigateToEventDetail,
          isLoading: true,
          shrinkWrap: true,
        ),
        error: (_, __) => EventsGrid(
          events: const [],
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Errore nel caricamento delle partecipazioni.',
          shrinkWrap: true,
        ),
      );
    }
  }

  /// Navigate to edit profile screen
  void _navigateToEditProfile(Profile profile) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: const EditProfileScreen()),
    );
  }

  /// Navigate to profile photo viewer
  void _navigateToPhotoViewer(Profile profile) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoViewerScreen(profile: profile);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Navigate to settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: const SettingsScreen()),
    );
  }

  /// Navigate to event detail
  void _navigateToEventDetail(Event event) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: event.id)),
    );
  }

  /// Build tutor section - shows BecomeTutorCard or TutorProfileSection
  ///
  /// T031: Show BecomeTutorCard when tutorProfile == null
  /// T032: Show TutorProfileSection with "Modifica" button when tutor
  Widget _buildTutorSection() {
    final tutorAsync = ref.watch(currentTutorProfileProvider);

    return tutorAsync.when(
      data: (tutorProfile) {
        if (tutorProfile == null) {
          // Not a tutor - show CTA to become one
          return BecomeTutorCard(
            onTap: _navigateToBecomeTutor,
          );
        } else {
          // Is a tutor - show their profile section
          return TutorProfileSection(
            profile: tutorProfile,
            isOwnProfile: true,
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Navigate to become tutor screen
  void _navigateToBecomeTutor() {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: const BecomeTutorScreen()),
    );
  }

  /// Navigate to moderation screen
  void _navigateToModeration() {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: const ModerationScreen()),
    );
  }

  /// Build moderation button with pending count badge
  Widget _buildModerationButton() {
    final pendingCountAsync = ref.watch(pendingCountProvider);

    return TextButton(
      onPressed: _navigateToModeration,
      style: TextButton.styleFrom(
        backgroundColor: NovaColors.brandViolet.withValues(alpha: 0.1),
        foregroundColor: NovaColors.brandViolet,
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularFull,
          side: BorderSide(color: NovaColors.brandViolet),
        ),
        padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: NovaColors.brandViolet),
          SizedBox(width: NovaSpacing.xsmall),
          Text(
            'Moderazione',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.brandViolet,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Badge with pending count
          pendingCountAsync.when(
            data: (count) {
              if (count > 0) {
                return Container(
                  margin: EdgeInsets.only(left: NovaSpacing.xsmall),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: NovaColors.brandViolet,
                    borderRadius: NovaRadius.circularXs,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: NovaTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            const Expanded(
              child: Center(
                child: AdaptiveLoadingIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView(Object error) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(NovaSpacing.large),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: NovaColors.error(context),
                      ),
                      SizedBox(height: NovaSpacing.medium),
                      Text(
                        'Errore nel caricare il profilo',
                        style: NovaTypography.headingSmall.copyWith(
                          color: NovaColors.textPrimary(context),
                        ),
                        textAlign: TextAlign.center,
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
                      AdaptiveButton(
                        type: AdaptiveButtonType.primary,
                        onPressed: () {
                          ref.invalidate(currentProfileProvider);
                        },
                        child: Text(
                          'Riprova',
                          style: NovaTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to convert SizedBox to SliverToBoxAdapter
extension SizedBoxSliver on SizedBox {
  SliverToBoxAdapter toSliver() => SliverToBoxAdapter(child: this);
}
