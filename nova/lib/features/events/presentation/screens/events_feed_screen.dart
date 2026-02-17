// Screen: EventsFeedScreen
// Feature: 003-events-feed
// Purpose: Main feed with infinite scroll, pull-to-refresh, and empty state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/models/auth_state.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/events_feed_provider.dart';
import '../providers/event_engagement_provider.dart';
import '../providers/event_likes_notifier.dart';
import '../providers/event_help_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pending_event_banner.dart';
import 'event_detail_screen.dart';

class EventsFeedScreen extends ConsumerStatefulWidget {
  /// Whether to show the AppBar (default: true)
  /// Set to false when used inside MainFeedScreen's TabBarView
  final bool showAppBar;

  /// Whether to disable the built-in RefreshIndicator
  /// Set to true when parent handles refresh (e.g., MainFeedScreen with Instagram-style indicator)
  final bool disableRefresh;

  const EventsFeedScreen({
    super.key,
    this.showAppBar = true,
    this.disableRefresh = false,
  });

  @override
  ConsumerState<EventsFeedScreen> createState() => _EventsFeedScreenState();
}

class _EventsFeedScreenState extends ConsumerState<EventsFeedScreen> {
  ScrollController? _scrollController;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    // Only create own scroll controller when showing AppBar (standalone mode)
    // When nested in NestedScrollView, use primary scroll controller
    if (widget.showAppBar) {
      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);

      // Restore scroll position after widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final savedPosition = ref.read(eventsFeedScrollPositionProvider);
        if (savedPosition > 0 && _scrollController!.hasClients) {
          _scrollController!.jumpTo(savedPosition);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    super.dispose();
  }

  /// Pagination trigger: Load next page when within 3 items of bottom
  void _onScroll() {
    final controller = _scrollController;
    if (controller != null &&
        controller.position.pixels >=
            controller.position.maxScrollExtent - 500) {
      ref.read(eventsFeedProvider.notifier).loadNextPage();
    }
  }

  /// Handle scroll notifications (for nested scroll mode)
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 500) {
        ref.read(eventsFeedProvider.notifier).loadNextPage();
      }
    }
    return false; // Allow notification to continue bubbling
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    await ref.read(eventsFeedProvider.notifier).refresh();
  }

  /// Open event detail screen
  void _openEventDetail(String eventId) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: eventId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedState = ref.watch(eventsFeedProvider);

    final bodyContent = Column(
      children: [
        // Offline banner
        if (_isOffline)
          OfflineBanner(
            isOffline: _isOffline,
            onDismiss: () {
              setState(() {
                _isOffline = false;
              });
            },
          ),

        // Feed content
        Expanded(
          child: feedState.when(
            data: (state) => _buildFeedContent(state),
            loading: () => _buildLoadingIndicator(),
            error: (error, stack) => _buildErrorState(error.toString()),
          ),
        ),
      ],
    );

    // Conditionally wrap with Scaffold + AppBar
    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: NovaColors
            .backgroundLight, // Pure white background (Instagram-style)
        appBar: AppBar(
          title: Text(
            'Eventi',
            style: NovaTextStyles.h2.copyWith(
              color: isDark
                  ? NovaColors.textPrimaryDark
                  : NovaColors.textPrimaryLight,
            ),
          ),
          backgroundColor:
              isDark ? NovaColors.surfaceDark : NovaColors.surfaceLight,
          elevation: 0,
          centerTitle: true,
          actions: [
            // Show login button for guests, logout button for authenticated users
            _buildAuthAction(context),
          ],
        ),
        body: bodyContent,
      );
    } else {
      return bodyContent;
    }
  }

  Widget _buildFeedContent(EventsFeedState state) {
    // Get pending events for current user
    final pendingEventsAsync = ref.watch(userPendingEventsProvider);
    final pendingEvents = pendingEventsAsync.valueOrNull ?? [];

    // Show empty state if no events (both pending and approved)
    if (state.events.isEmpty && pendingEvents.isEmpty && !state.isLoadingMore) {
      return _buildEmptyState();
    }

    // Fetch engagement metrics for all events in batch
    final eventIds = state.events.map((e) => e.id).toList();
    final engagementAsync = ref.watch(batchEventEngagementProvider(eventIds));
    final engagementMap = engagementAsync.valueOrNull ?? {};

    // Fetch help requests for all events in batch
    // Use joined string as key to prevent infinite rebuilds (List creates new instance each time)
    final eventIdsKey = eventIds.join(',');
    final helpRequestsAsync = ref.watch(batchHelpRequestsKeyProvider(eventIdsKey));
    final helpRequestsMap = helpRequestsAsync.valueOrNull ?? {};

    // Initialize likes provider with engagement data (only for events not yet initialized)
    final likesNotifier = ref.read(eventLikesProvider.notifier);
    for (final event in state.events) {
      final engagement = engagementMap[event.id];
      if (engagement != null) {
        likesNotifier.initializeEvent(
          eventId: event.id,
          isLiked: engagement.isLiked,
          likeCount: engagement.likeCount,
        );
      }
    }

    // Calculate item count: pending events + approved events + loading indicator
    final itemCount = pendingEvents.length +
        state.events.length +
        (state.isLoadingMore ? 1 : 0);

    final listView = ListView.builder(
      // Use own controller only in standalone mode
      // In nested mode, use primary scroll controller from NestedScrollView
      controller: widget.showAppBar ? _scrollController : null,
      primary: !widget.showAppBar, // Use PrimaryScrollController when nested
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(
        left: 2.0,
        right: 2.0,
        top: NovaSpacing.xs,
        bottom: 100, // Account for bottom navbar + safe area
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // First: Pending events banner (compact) at top
        if (index < pendingEvents.length) {
          final pendingEvent = pendingEvents[index];
          return PendingEventBanner(
            event: pendingEvent,
            onTap: () => _openEventDetail(pendingEvent.id),
          );
        }

        // Adjust index for approved events
        final approvedIndex = index - pendingEvents.length;

        // Show loading indicator at bottom while paginating
        if (approvedIndex == state.events.length) {
          return _buildPaginationLoader();
        }

        final event = state.events[approvedIndex];
        final engagement = engagementMap[event.id] ?? const EventEngagement();

        // Convert help requests to HelpRequestInfo for display
        final eventHelpRequests = helpRequestsMap[event.id] ?? [];
        final helpRequestInfos = eventHelpRequests
            .map((r) => HelpRequestInfo(
                  id: r.id,
                  description: r.description,
                  isFulfilled: r.isFulfilled,
                ))
            .toList();

        // EventCard with staggered animation for smooth list loading
        // Key on StaggeredListItem preserves child's local state during scroll/rebuild
        return StaggeredListItem(
          key: ValueKey(event.id),
          index: approvedIndex,
          child: EventCard(
            event: event,
            organizerName: event.creatorName ?? 'Organizzatore',
            organizerClass: event.creatorClass ?? '',
            organizerAvatarUrl: event.creatorAvatarUrl,
            likeCount: engagement.likeCount,
            commentCount: engagement.commentCount,
            participantCount: engagement.participantCount,
            isLiked: engagement.isLiked,
            isParticipating: engagement.isParticipating,
            collaborators: const [], // TODO: Fetch real collaborators
            helpRequests: helpRequestInfos,
          ),
        );
      },
    );

    // Wrap with NotificationListener for pagination in nested mode
    Widget scrollableContent = widget.showAppBar
        ? listView
        : NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: listView,
          );

    // Conditionally wrap with RefreshIndicator (disabled when parent handles refresh)
    if (widget.disableRefresh) {
      return scrollableContent;
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      displacement: 40.0,
      child: scrollableContent,
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildPaginationLoader() {
    return const Padding(
      padding: EdgeInsets.all(NovaSpacing.l),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: isDark
                  ? NovaColors.textTertiaryDark
                  : NovaColors.textTertiaryLight,
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Nessun evento',
              style: NovaTextStyles.h3.copyWith(
                color: isDark
                    ? NovaColors.textPrimaryDark
                    : NovaColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Non ci sono eventi approvati al momento.\nTorna più tardi!',
              textAlign: TextAlign.center,
              style: NovaTextStyles.body.copyWith(
                color: isDark
                    ? NovaColors.textSecondaryDark
                    : NovaColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: isDark ? NovaColors.errorDark : NovaColors.errorLight,
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Errore',
              style: NovaTextStyles.h3.copyWith(
                color: isDark
                    ? NovaColors.textPrimaryDark
                    : NovaColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              error,
              textAlign: TextAlign.center,
              style: NovaTextStyles.body.copyWith(
                color: isDark
                    ? NovaColors.textSecondaryDark
                    : NovaColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: _onRefresh,
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build auth action button based on user state
  /// - Guest: "Accedi" button to go to login screen
  /// - Authenticated: "Esci" button to sign out
  Widget _buildAuthAction(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final isGuest = authState is AuthStateGuest;

    if (isGuest) {
      return IconButton(
        icon: const Icon(Icons.login_rounded),
        onPressed: () => ref.read(authNotifierProvider.notifier).showLogin(),
        tooltip: 'Accedi',
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.logout_rounded),
        onPressed: () => _handleSignOut(context),
        tooltip: 'Esci',
      );
    }
  }

  /// Handle sign out button press
  Future<void> _handleSignOut(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esci'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Sign out via auth notifier
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}
