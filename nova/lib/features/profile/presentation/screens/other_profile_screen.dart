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
import '../widgets/profile_tabs.dart';
import '../widgets/events_grid.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../../core/animations/page_transitions.dart';
import 'profile_photo_viewer_screen.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_button.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
// Tutoring feature imports (T045-T048)
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/widgets/tutor_profile_section.dart';
// UGC Safety feature imports (T032)
import '../../../safety/data/models/report.dart';
import '../../../safety/presentation/widgets/report_sheet.dart';
import '../../../safety/presentation/widgets/block_button.dart';
import '../../../safety/presentation/providers/block_provider.dart';
import '../../../safety/presentation/widgets/block_button.dart';
import '../../../safety/presentation/providers/block_provider.dart';

/// Screen for viewing other users' profiles (OPTIMIZED)
///
/// **Features**:
/// - Compact profile header with avatar, name, class, bio, badges
/// - Tutor section if user is a tutor
/// - Events grid only shown if user has events
///
/// **Optimizations**:
/// - Removed duplicate stats (ProfileHeader already shows them)
/// - Removed ProfileTabs (only one tab was visible anyway)
/// - Events section hidden if empty
///
/// **Privacy Enforcement**:
/// - RLS policies ensure only public profiles visible
/// - Shows user's created events and participations via tabs
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
  ProfileTab _selectedTab = ProfileTab.eventi;

  @override
  Widget build(BuildContext context) {
    // UGC Safety: Check if current user can view this profile (T047)
    // If blocked by profile owner, show "Profilo non disponibile"
    final canViewAsync = ref.watch(canViewProfileProvider(widget.userId));

    return canViewAsync.when(
      skipLoadingOnRefresh: true,
      data: (canView) {
        if (!canView) {
          // User is blocked - show privacy error
          return _buildErrorView(Exception('blocked'));
        }
        // User can view - proceed with loading profile
        final profileAsync = ref.watch(otherProfileProvider(widget.userId));
        final statsAsync = ref.watch(otherProfileStatsProvider(widget.userId));

        return profileAsync.when(
          skipLoadingOnRefresh: true,
          data: (profile) => _buildProfileView(profile, statsAsync),
          loading: () => _buildLoadingView(),
          error: (error, stack) => _buildErrorView(error),
        );
      },
      loading: () => _buildLoadingView(),
      error: (error, stack) => _buildErrorView(error),
    );
  }

  /// Build profile view with data (OPTIMIZED)
  Widget _buildProfileView(
      Profile? profile, AsyncValue<ProfileStats?> statsAsync) {
    if (profile == null) {
      return _buildErrorView(Exception('Profile not found'));
    }

    // Get stats for conditional rendering
    final stats = statsAsync.valueOrNull;
    final hasEventsOrParticipations = stats != null &&
        (stats.eventsCreatedCount > 0 || stats.participationsCount > 0);

    return AdaptiveScaffold(
      appBar: _buildAppBar(profile),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(otherProfileProvider(widget.userId));
          ref.invalidate(otherProfileStatsProvider(widget.userId));
          ref.invalidate(otherUserCreatedEventsProvider(widget.userId));
          ref.invalidate(otherUserParticipatingEventsProvider(widget.userId));
        },
        child: CustomScrollView(
          slivers: [
            // Profile header with stats (no duplicate stats widget needed)
            SliverToBoxAdapter(
              child: ProfileHeader(
                profile: profile,
                stats: statsAsync.valueOrNull,
                isOwnProfile: false,
                onAvatarTap: () => _navigateToPhotoViewer(profile),
                onEventiTap: () =>
                    setState(() => _selectedTab = ProfileTab.eventi),
                onPartecipazioniTap: () =>
                    setState(() => _selectedTab = ProfileTab.partecipazioni),
              ),
            ),

            // Tutor profile section (if user is a tutor)
            SliverToBoxAdapter(
              child: _buildTutorSection(profile),
            ),

            // Events section - only show if user has events or participations
            if (hasEventsOrParticipations) ...[
              // Tabs (Eventi / Partecipazioni)
              SliverToBoxAdapter(
                child: ProfileTabs(
                  selectedTab: _selectedTab,
                  onTabChanged: (tab) => setState(() => _selectedTab = tab),
                  showPartecipazioni: true,
                ),
              ),
              // Events grid based on selected tab
              SliverToBoxAdapter(
                child: _buildEventsGrid(),
              ),
            ],

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar with profile name and actions menu
  PreferredSizeWidget _buildAppBar(Profile profile) {
    final displayName =
        profile.fullName.isNotEmpty ? profile.fullName : profile.username;

    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text(
          displayName,
          style: NovaTypography.headingMedium,
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: '',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis),
          onPressed: () => _showActionSheet(profile),
        ),
      );
    } else {
      return AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: NovaColors.textPrimary(context),
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          displayName,
          style: NovaTypography.headingMedium,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: NovaColors.background(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionSheet(profile),
          ),
        ],
      );
    }
  }

  /// Show action sheet with Report and Block options
  void _showActionSheet(Profile profile) {
    debugPrint('[ActionSheet] Opening for user: ${profile.userId}');
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                debugPrint('[ActionSheet] Block tapped');
                Navigator.pop(sheetContext);
                _showBlockConfirmation(profile);
              },
              child: const Text('Blocca utente'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                debugPrint('[ActionSheet] Report tapped');
                Navigator.pop(sheetContext);
                _showReportSheet(profile);
              },
              child: const Text('Segnala'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Annulla'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Block option
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blocca utente'),
                subtitle: const Text('Non vedrai più i suoi contenuti'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation(profile);
                },
              ),
              // Report option
              ListTile(
                leading: Icon(
                  Icons.flag_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Segnala',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Segnala profilo inappropriato'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportSheet(profile);
                },
              ),
              SizedBox(height: NovaSpacing.medium),
            ],
          ),
        ),
      );
    }
  }

  /// Show report sheet for profile
  void _showReportSheet(Profile profile) {
    debugPrint('[Report] Showing report sheet for: ${profile.userId}');
    ReportCategorySheet.show(
      context,
      contentType: ReportableContentType.profile,
      contentId: profile.userId,
    );
  }

  /// Show block confirmation dialog
  void _showBlockConfirmation(Profile profile) {
    debugPrint('[Block] Showing confirmation for: ${profile.userId}');
    final displayName =
        profile.fullName.isNotEmpty ? profile.fullName : profile.username;

    showDialog(
      context: context,
      builder: (dialogContext) => BlockConfirmationDialog(
        userId: profile.userId,
        userName: displayName,
        onConfirm: () async {
          debugPrint('[Block] Confirm pressed, blocking user...');
          Navigator.of(dialogContext).pop();
          final success = await ref
              .read(blockNotifierProvider.notifier)
              .blockUser(profile.userId);
          debugPrint('[Block] Block result: $success');
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$displayName è stato bloccato'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back after blocking
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  /// Build events grid based on selected tab
  Widget _buildEventsGrid() {
    if (_selectedTab == ProfileTab.eventi) {
      // Load user's created events
      final createdEventsAsync =
          ref.watch(otherUserCreatedEventsProvider(widget.userId));
      return createdEventsAsync.when(
        data: (events) => EventsGrid(
          events: events,
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Nessun evento creato.',
          shrinkWrap: true,
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
      final participatingEventsAsync =
          ref.watch(otherUserParticipatingEventsProvider(widget.userId));
      return participatingEventsAsync.when(
        data: (events) => EventsGrid(
          events: events,
          onEventTap: _navigateToEventDetail,
          emptyMessage: 'Nessuna partecipazione.',
          shrinkWrap: true,
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

  /// Navigate to full-screen photo viewer (read-only for other profiles)
  void _navigateToPhotoViewer(Profile profile) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoViewerScreen(
            profile: profile,
            isOwnProfile: false,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Navigate to event detail
  void _navigateToEventDetail(Event event) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: event.id)),
    );
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
          authorName: profile.fullName.isNotEmpty
              ? profile.fullName
              : profile.username, // For ContactTutorSheet
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Profilo'),
          previousPageTitle: '',
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
    // Check if error is privacy-related (profile hidden, deleted, or blocked)
    // T047: "blocked" indicates the viewer is blocked by this profile's owner
    final isPrivacyError = error.toString().contains('No rows') ||
        error.toString().contains('not found') ||
        error.toString().contains('visible') ||
        error.toString().contains('blocked');

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
              color: isPrivacyError
                  ? NovaColors.textTertiary(context)
                  : NovaColors.error(context),
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
          previousPageTitle: '',
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
