/// Search empty state widget
///
/// Shows initial state (before search) or no results state.
library;

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Empty state types
enum SearchEmptyStateType {
  /// Initial state before any search
  initial,

  /// No results found for query
  noResults,
}

/// Widget for displaying search empty states
class SearchEmptyState extends StatelessWidget {
  final SearchEmptyStateType type;
  final String? query;

  const SearchEmptyState({
    super.key,
    required this.type,
    this.query,
  });

  /// Initial state before search
  const SearchEmptyState.initial({super.key})
      : type = SearchEmptyStateType.initial,
        query = null;

  /// No results found
  const SearchEmptyState.noResults({super.key, required String searchQuery})
      : type = SearchEmptyStateType.noResults,
        query = searchQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icon,
              size: 64,
              color: NovaColors.textTertiaryStatic,
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              _title,
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textSecondaryStatic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NovaSpacing.xs),
            Text(
              _subtitle,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textTertiaryStatic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (type) {
      case SearchEmptyStateType.initial:
        return Icons.search;
      case SearchEmptyStateType.noResults:
        return Icons.search_off;
    }
  }

  String get _title {
    switch (type) {
      case SearchEmptyStateType.initial:
        return 'Cerca eventi e persone';
      case SearchEmptyStateType.noResults:
        return 'Nessun risultato';
    }
  }

  String get _subtitle {
    switch (type) {
      case SearchEmptyStateType.initial:
        return 'Digita almeno 2 caratteri per iniziare';
      case SearchEmptyStateType.noResults:
        return 'Nessun risultato per "${query ?? ""}"';
    }
  }
}
