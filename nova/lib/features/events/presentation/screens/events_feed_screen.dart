// Screen: EventsFeedScreen
// Feature: 003-events-feed
// Purpose: Main feed with infinite scroll, pull-to-refresh, and empty state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/events_feed_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/offline_banner.dart';

class EventsFeedScreen extends ConsumerStatefulWidget {
  /// Whether to show the AppBar (default: true)
  /// Set to false when used inside MainFeedScreen's TabBarView
  final bool showAppBar;

  const EventsFeedScreen({
    super.key,
    this.showAppBar = true,
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
        controller.position.pixels >= controller.position.maxScrollExtent - 500) {
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
        backgroundColor: const Color(0xFFFFFFFF), // Pure white background (Instagram-style)
        appBar: AppBar(
          title: Text(
            'Eventi',
            style: NovaTextStyles.h2.copyWith(
              color: isDark
                  ? NovaColors.textPrimaryDark
                  : NovaColors.textPrimaryLight,
            ),
          ),
          backgroundColor: isDark ? NovaColors.surfaceDark : NovaColors.surfaceLight,
          elevation: 0,
          centerTitle: true,
          actions: [
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _handleSignOut(context),
              tooltip: 'Esci',
            ),
          ],
        ),
        body: bodyContent,
      );
    } else {
      return bodyContent;
    }
  }

  Widget _buildFeedContent(EventsFeedState state) {
    // Show empty state if no events
    if (state.events.isEmpty && !state.isLoadingMore) {
      return _buildEmptyState();
    }

    // Calculate item count: events + loading indicator
    final itemCount = state.events.length + (state.isLoadingMore ? 1 : 0);

    final listView = ListView.builder(
      // Use own controller only in standalone mode
      // In nested mode, use primary scroll controller from NestedScrollView
      controller: widget.showAppBar ? _scrollController : null,
      primary: !widget.showAppBar, // Use PrimaryScrollController when nested
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 2.0,
        vertical: NovaSpacing.m,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Show loading indicator at bottom while paginating
        if (index == state.events.length) {
          return _buildPaginationLoader();
        }

        final event = state.events[index];
        // EventCard now has internal tap-to-expand, no navigation needed
        return EventCard(
          event: event,
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
