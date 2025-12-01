/// Search screen
///
/// Main search screen with adaptive search bar and results sections.
/// Supports live search with 500ms debouncing, search history, and highlighting.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
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
import '../widgets/search_results_section.dart';
import '../widgets/recent_searches_widget.dart';
import '../widgets/search_empty_state.dart';
import '../widgets/search_loading_skeleton.dart';

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Events section
          SearchResultsSection(
            title: 'Eventi',
            count: results.events.length,
            showDivider: results.profiles.isNotEmpty,
            children: results.events.map<Widget>((event) {
              return EventSearchTile(
                event: event,
                highlightQuery: query,
                onTap: () => _navigateToEvent(event.id),
              );
            }).toList(),
          ),
          // Profiles section
          SearchResultsSection(
            title: 'Utenti',
            count: results.profiles.length,
            showDivider: false,
            children: results.profiles.map<Widget>((profile) {
              return ProfileSearchTile(
                profile: profile,
                highlightQuery: query,
                onTap: () => _navigateToProfile(profile.id),
              );
            }).toList(),
          ),
          // From cache indicator
          if (results.isFromCache)
            Padding(
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
            ),
        ],
      ),
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
