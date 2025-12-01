// Screen: ProfileScreen
// Feature: 006-user-profile (User Story 1 - T039)
// Purpose: Own profile view with header, stats, tabs, edit button, settings icon

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart' as widgets;
import '../widgets/profile_tabs.dart';
import '../widgets/events_grid.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_button.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
// Tutoring feature imports
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/widgets/become_tutor_card.dart';
import '../../../tutoring/presentation/widgets/tutor_profile_section.dart';
import '../../../tutoring/presentation/screens/become_tutor_screen.dart';

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
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh profile and stats
          ref.invalidate(currentProfileProvider);
          ref.invalidate(currentProfileStatsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: ProfileHeader(
                profile: profile,
                isOwnProfile: true,
              ),
            ),

            // Profile stats
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => widgets.UserProfileStats(stats: stats),
                loading: () => Padding(
                  padding: EdgeInsets.all(NovaSpacing.medium),
                  child: const AdaptiveLoadingIndicator(),
                ),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ),

            // Tutor profile section (T030-T032: FR-019)
            SliverToBoxAdapter(
              child: _buildTutorSection(),
            ),

            // Edit Profile button
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: NovaSpacing.large),
                child: AdaptiveButton(
                  onPressed: () => _navigateToEditProfile(profile),
                  backgroundColor: NovaColors.backgroundSecondary(context),
                  child: Text(
                    'Modifica Profilo',
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

            // Events grid based on selected tab
            SliverFillRemaining(
              child: _buildEventsGrid(profile, statsAsync),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar with settings icon
  PreferredSizeWidget _buildAppBar() {
    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text(
          'Profilo',
          style: NovaTypography.headingMedium,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _navigateToSettings,
          child: const Icon(
            CupertinoIcons.settings,
            size: 24,
          ),
        ),
      );
    } else {
      return AppBar(
        title: Text(
          'Profilo',
          style: NovaTypography.headingMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 24),
            onPressed: _navigateToSettings,
          ),
        ],
      );
    }
  }

  /// Build events grid based on selected tab
  Widget _buildEventsGrid(Profile profile, AsyncValue<ProfileStats> statsAsync) {
    // TODO(T037): Replace with actual event queries
    // For now, show placeholder empty state

    if (_selectedTab == ProfileTab.eventi) {
      return EventsGrid(
        events: const [], // TODO: Load created events
        onEventTap: _navigateToEventDetail,
        emptyMessage: 'Nessun evento creato.\nCrea il tuo primo evento!',
      );
    } else {
      return EventsGrid(
        events: const [], // TODO: Load participated events
        onEventTap: _navigateToEventDetail,
        emptyMessage: 'Nessuna partecipazione.\nPartecipa al tuo primo evento!',
      );
    }
  }

  /// Navigate to edit profile screen
  void _navigateToEditProfile(Profile profile) {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (_) => const EditProfileScreen(),
            )
          : MaterialPageRoute(
              builder: (_) => const EditProfileScreen(),
            ),
    );
  }

  /// Navigate to settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (_) => const SettingsScreen())
          : MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  /// Navigate to event detail
  void _navigateToEventDetail(dynamic event) {
    // TODO: Navigate to EventDetailScreen
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
      Platform.isIOS
          ? CupertinoPageRoute(builder: (_) => const BecomeTutorScreen())
          : MaterialPageRoute(builder: (_) => const BecomeTutorScreen()),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: const Center(
        child: AdaptiveLoadingIndicator(),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView(Object error) {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: Center(
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
                onPressed: () {
                  ref.invalidate(currentProfileProvider);
                },
                backgroundColor: NovaColors.brandViolet,
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
    );
  }
}

/// Extension to convert SizedBox to SliverToBoxAdapter
extension SizedBoxSliver on SizedBox {
  SliverToBoxAdapter toSliver() => SliverToBoxAdapter(child: this);
}
