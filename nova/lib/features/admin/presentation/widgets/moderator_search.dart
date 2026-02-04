// =====================================================================
// ModeratorSearch Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Search widget for finding users to promote to moderator
// Architecture: Debounced text field with search results
// =====================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_text_field.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';
import 'package:nova/features/admin/presentation/providers/admin_actions_notifier.dart';

/// State provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results
final searchResultsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty || query.length < 2) {
    return [];
  }

  final repository = ref.watch(adminRepositoryProvider);
  return repository.searchUsers(query);
});

/// Moderator search widget with debounced input
///
/// Allows admin to search for users by name, email, or class
/// and promote them to moderator role.
class ModeratorSearch extends ConsumerStatefulWidget {
  const ModeratorSearch({super.key});

  @override
  ConsumerState<ModeratorSearch> createState() => _ModeratorSearchState();
}

class _ModeratorSearchState extends ConsumerState<ModeratorSearch> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _promoteUser(Map<String, dynamic> user) async {
    // Show confirmation dialog first (T063)
    final confirmed = await _showPromotionDialog(user);

    if (confirmed == true && mounted) {
      await ref.read(adminActionsNotifierProvider.notifier).promoteUser(
            user['id'] as String,
            user['full_name'] as String,
          );

      // Clear search after successful promotion
      _clearSearch();

      // Show success message
      if (mounted) {
        final actionsState = ref.read(adminActionsNotifierProvider);
        if (actionsState.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(actionsState.successMessage!),
              backgroundColor: NovaColors.success(context),
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showPromotionDialog(Map<String, dynamic> user) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promuovi a moderatore'),
        content: Text(
          '${user['full_name']} (${user['class_name']}) diventerà moderatore e potrà approvare/rifiutare eventi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Promuovi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final actionsState = ref.watch(adminActionsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field
        AdaptiveTextField(
          controller: _searchController,
          placeholder: 'Cerca per nome, email o classe...',
          prefix: Icon(
            Icons.search,
            color: NovaColors.textTertiary(context),
          ),
          suffix: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: NovaColors.textTertiary(context),
                  ),
                  onPressed: _clearSearch,
                  tooltip: 'Cancella',
                )
              : null,
        ),

        const SizedBox(height: NovaSpacing.m),

        // Error message
        if (actionsState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.error(context).withValues(alpha: 0.1),
              borderRadius: NovaRadius.circularM,
            ),
            child: Text(
              actionsState.error!,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.error(context),
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.m),
        ],

        // Search results
        searchResults.when(
          data: (results) {
            if (_searchController.text.isEmpty) {
              return const SizedBox.shrink();
            }

            if (results.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(NovaSpacing.l),
                decoration: BoxDecoration(
                  color: NovaColors.surface(context),
                  borderRadius: NovaRadius.circularM,
                ),
                child: Center(
                  child: Text(
                    'Nessun risultato trovato',
                    style: NovaTextStyles.body.copyWith(
                      color: NovaColors.textTertiary(context),
                    ),
                  ),
                ),
              );
            }

            return Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                borderRadius: NovaRadius.circularM,
                border: Border.all(
                  color: NovaColors.border(context),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: NovaColors.divider(context),
                ),
                itemBuilder: (context, index) {
                  final user = results[index];
                  return ListTile(
                    title: Text(
                      user['full_name'] as String,
                      style: NovaTextStyles.bodyBold,
                    ),
                    subtitle: Text(
                      '${user['email']} • ${user['class_name']}',
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                    trailing: actionsState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AdaptiveButton(
                            onPressed: () => _promoteUser(user),
                            type: AdaptiveButtonType.primary,
                            child: const Text('Promuovi'),
                          ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.error(context).withValues(alpha: 0.1),
              borderRadius: NovaRadius.circularM,
            ),
            child: Text(
              'Errore: $err',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.error(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
