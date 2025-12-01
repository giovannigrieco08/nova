/// Search screen
///
/// Main search screen with adaptive search bar and results sections.
/// Supports live search with 500ms debouncing, search history, and highlighting.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/features/events/presentation/screens/event_detail_screen.dart';
import 'package:nova/features/profile/presentation/screens/other_profile_screen.dart';
import '../providers/search_provider.dart';
import '../providers/search_history_provider.dart';
import '../widgets/adaptive_search_bar.dart';
import '../widgets/event_search_tile.dart';
import '../widgets/profile_search_tile.dart';
import '../widgets/recent_searches_widget.dart';
import '../widgets/search_empty_state.dart';
import '../widgets/search_loading_skeleton.dart';
import '../widgets/animated_search_result.dart';

/// Main search screen
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Cerca'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(CupertinoIcons.back),
          ),
        ),
        child: SafeArea(
          child: _buildContent(searchState, notifier),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _buildContent(searchState, notifier),
      ),
    );
  }

  Widget _buildContent(SearchState searchState, SearchNotifier notifier) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(NovaSpacing.l),
          child: AdaptiveSearchBar(
            initialQuery: searchState.query,
            autofocus: true,
            onChanged: (query) {
              notifier.updateQuery(query);
            },
            onSubmitted: (query) {
              _onSearchSubmitted(query, notifier);
            },
            onClear: () {
              notifier.clear();
            },
          ),
        ),
        // Offline banner
        if (searchState.isOffline) _buildOfflineBanner(),
        // Results
        Expanded(
          child: searchState.results.when(
            data: (results) {
              if (searchState.query.trim().length < 2) {
                return _buildInitialState(notifier);
              }
              if (!results.hasResults) {
                return SearchEmptyState.noResults(
                  searchQuery: searchState.query,
                );
              }
              return _buildResults(results, searchState.query);
            },
            loading: () => const SearchLoadingSkeleton(),
            error: (error, stack) => _buildErrorState(error.toString()),
          ),
        ),
      ],
    );
  }

  void _onSearchSubmitted(String query, SearchNotifier notifier) {
    notifier.searchNow(query);
    // Save to history
    if (query.trim().length >= 2) {
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.s,
      ),
      color: NovaColors.warningLight.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 16,
            color: NovaColors.warningStatic,
          ),
          const SizedBox(width: NovaSpacing.xs),
          Text(
            'Ricerca offline - risultati dalla cache',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.warningStatic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(SearchNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Recent searches
          RecentSearchesWidget(
            onQuerySelected: (query) {
              notifier.searchNow(query);
              ref.read(searchHistoryProvider.notifier).addQuery(query);
            },
            onClearAll: () {},
          ),
          // Empty state
          const SearchEmptyState.initial(),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: NovaColors.errorStatic,
          ),
          const SizedBox(height: NovaSpacing.l),
          Text(
            'Errore di ricerca',
            style: NovaTextStyles.bodyLarge.copyWith(
              color: NovaColors.textSecondaryStatic,
            ),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
            child: Text(
              error,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiaryStatic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    dynamic results,
    String query,
  ) {
    // Save successful search to history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (results.hasResults && query.trim().length >= 2) {
        ref.read(searchHistoryProvider.notifier).addQuery(query);
      }
    });

    // Build flat list of items for ListView.builder (60fps optimization)
    final items = <_SearchResultItem>[];
    int animationIndex = 0;

    // Add events section header
    if (results.events.isNotEmpty) {
      items.add(_SearchResultItem(
        type: _ItemType.sectionHeader,
        title: 'Eventi',
        count: results.events.length,
        showDivider: results.profiles.isNotEmpty,
        animationIndex: animationIndex++,
      ));
      // Add event tiles
      for (final event in results.events) {
        items.add(_SearchResultItem(
          type: _ItemType.event,
          event: event,
          query: query,
          animationIndex: animationIndex++,
        ));
      }
    }

    // Add profiles section header
    if (results.profiles.isNotEmpty) {
      items.add(_SearchResultItem(
        type: _ItemType.sectionHeader,
        title: 'Utenti',
        count: results.profiles.length,
        showDivider: false,
        animationIndex: animationIndex++,
      ));
      // Add profile tiles
      for (final profile in results.profiles) {
        items.add(_SearchResultItem(
          type: _ItemType.profile,
          profile: profile,
          query: query,
          animationIndex: animationIndex++,
        ));
      }
    }

    // Add cache indicator
    if (results.isFromCache) {
      items.add(_SearchResultItem(
        type: _ItemType.cacheIndicator,
        animationIndex: animationIndex++,
      ));
    }

    // Use ListView.builder for 60fps performance
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      // Optimize scroll performance
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final item = items[index];
        return AnimatedSearchResult(
          index: item.animationIndex,
          child: _buildResultItem(item),
        );
      },
    );
  }

  Widget _buildResultItem(_SearchResultItem item) {
    switch (item.type) {
      case _ItemType.sectionHeader:
        return _buildSectionHeader(
          title: item.title!,
          count: item.count!,
          showDivider: item.showDivider!,
        );
      case _ItemType.event:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.xs,
          ),
          child: EventSearchTile(
            event: item.event!,
            highlightQuery: item.query,
            onTap: () => _navigateToEvent(item.event!.id),
          ),
        );
      case _ItemType.profile:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.xs,
          ),
          child: ProfileSearchTile(
            profile: item.profile!,
            highlightQuery: item.query,
            onTap: () => _navigateToProfile(item.profile!.id),
          ),
        );
      case _ItemType.cacheIndicator:
        return Padding(
          padding: const EdgeInsets.all(NovaSpacing.l),
          child: Center(
            child: Text(
              'Risultati dalla cache',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiaryStatic,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool showDivider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NovaSpacing.l,
            NovaSpacing.m,
            NovaSpacing.l,
            NovaSpacing.s,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: NovaTextStyles.h3.copyWith(
                  color: NovaColors.textPrimaryStatic,
                ),
              ),
              const SizedBox(width: NovaSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NovaSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.primaryLight,
                  borderRadius: NovaRadius.circularXs,
                ),
                child: Text(
                  count.toString(),
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.primaryStatic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(bottom: NovaSpacing.m),
            child: Divider(
              height: 1,
              color: NovaColors.dividerLight,
            ),
          ),
      ],
    );
  }

  void _navigateToEvent(String eventId) {
    if (PlatformUtils.isIOS) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => EventDetailScreen(eventId: eventId),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(eventId: eventId),
        ),
      );
    }
  }

  void _navigateToProfile(String userId) {
    if (PlatformUtils.isIOS) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => OtherProfileScreen(userId: userId),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtherProfileScreen(userId: userId),
        ),
      );
    }
  }
}

// ============================================================================
// HELPER CLASSES FOR LISTVIEW.BUILDER
// ============================================================================

/// Item types for flat list
enum _ItemType {
  sectionHeader,
  event,
  profile,
  cacheIndicator,
}

/// Wrapper for search result items in flat list
class _SearchResultItem {
  final _ItemType type;
  final String? title;
  final int? count;
  final bool? showDivider;
  final dynamic event;
  final dynamic profile;
  final String? query;
  final int animationIndex;

  const _SearchResultItem({
    required this.type,
    this.title,
    this.count,
    this.showDivider,
    this.event,
    this.profile,
    this.query,
    required this.animationIndex,
  });
}
