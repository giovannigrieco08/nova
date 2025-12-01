/// Search screen
///
/// Main search screen with adaptive search bar and results sections.
/// Supports live search with 500ms debouncing.

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
import '../widgets/adaptive_search_bar.dart';
import '../widgets/event_search_tile.dart';
import '../widgets/profile_search_tile.dart';
import '../widgets/search_results_section.dart';

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
              notifier.searchNow(query);
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
                return _buildInitialState();
              }
              if (!results.hasResults) {
                return _buildNoResultsState(searchState.query);
              }
              return _buildResults(results, searchState.query);
            },
            loading: () => _buildLoadingState(),
            error: (error, stack) => _buildErrorState(error.toString()),
          ),
        ),
      ],
    );
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

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: NovaColors.textTertiaryStatic,
          ),
          const SizedBox(height: NovaSpacing.l),
          Text(
            'Cerca eventi e persone',
            style: NovaTextStyles.bodyLarge.copyWith(
              color: NovaColors.textSecondaryStatic,
            ),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Text(
            'Digita almeno 2 caratteri per iniziare',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textTertiaryStatic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: NovaColors.textTertiaryStatic,
          ),
          const SizedBox(height: NovaSpacing.l),
          Text(
            'Nessun risultato',
            style: NovaTextStyles.bodyLarge.copyWith(
              color: NovaColors.textSecondaryStatic,
            ),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Text(
            'Nessun risultato per "$query"',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textTertiaryStatic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
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
