// Widget: UserSearchWidget
// Feature: 004-event-creation-moderation (Phase 7 - Co-Organizers)
// Purpose: Search and select co-organizers (max 3)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/providers/profile_search_provider.dart';

/// User search widget for co-organizer selection
///
/// Features:
/// - Debounced search (500ms)
/// - Max 3 selections enforced
/// - Selected users shown as removable chips
/// - Search by name or class
///
/// Usage:
/// ```dart
/// UserSearchWidget(
///   selectedUsers: currentCoOrganizers,
///   onSelectionChanged: (users) {
///     setState(() => coOrganizers = users);
///   },
/// )
/// ```
class UserSearchWidget extends ConsumerStatefulWidget {
  /// Currently selected users (co-organizers)
  final List<Profile> selectedUsers;

  /// Callback when selection changes
  final ValueChanged<List<Profile>> onSelectionChanged;

  /// Maximum number of selections allowed (default: 3)
  final int maxSelections;

  const UserSearchWidget({
    super.key,
    required this.selectedUsers,
    required this.onSelectionChanged,
    this.maxSelections = 3,
  });

  @override
  ConsumerState<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends ConsumerState<UserSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addUser(Profile user) {
    // Check if already selected
    if (widget.selectedUsers.any((u) => u.id == user.id)) {
      return;
    }

    // Check max selections
    if (widget.selectedUsers.length >= widget.maxSelections) {
      _showMaxSelectionsSnackbar();
      return;
    }

    // Add user
    final updated = [...widget.selectedUsers, user];
    widget.onSelectionChanged(updated);

    // Clear search
    _searchController.clear();
    ref.read(profileSearchProvider.notifier).clear();
  }

  void _removeUser(Profile user) {
    final updated =
        widget.selectedUsers.where((u) => u.id != user.id).toList();
    widget.onSelectionChanged(updated);
  }

  void _showMaxSelectionsSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Massimo ${widget.maxSelections} co-organizer',
          style: NovaTextStyles.body.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        backgroundColor: NovaColors.card(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.s),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(profileSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected users chips
        if (widget.selectedUsers.isNotEmpty)
          Wrap(
            spacing: NovaSpacing.s,
            runSpacing: NovaSpacing.s,
            children: widget.selectedUsers
                .map((user) => _UserChip(
                      user: user,
                      onRemove: () => _removeUser(user),
                    ))
                .toList(),
          ),
        if (widget.selectedUsers.isNotEmpty) const SizedBox(height: NovaSpacing.m),

        // Search input
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          enabled: widget.selectedUsers.length < widget.maxSelections,
          decoration: InputDecoration(
            hintText: 'Cerca per nome o classe...',
            hintStyle: NovaTextStyles.body.copyWith(
              color: NovaColors.textTertiary(context),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: NovaColors.textSecondary(context),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: NovaColors.textSecondary(context),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(profileSearchProvider.notifier).clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: NovaColors.surface(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NovaRadius.s),
              borderSide: BorderSide(
                color: NovaColors.border(context),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NovaRadius.s),
              borderSide: BorderSide(
                color: NovaColors.border(context),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NovaRadius.s),
              borderSide: BorderSide(
                color: NovaColors.primary(context),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NovaRadius.s),
              borderSide: BorderSide(
                color: NovaColors.border(context).withOpacity(0.5),
              ),
            ),
          ),
          style: NovaTextStyles.body.copyWith(
            color: NovaColors.textPrimary(context),
          ),
          onChanged: (query) {
            ref.read(profileSearchProvider.notifier).search(query);
          },
        ),

        // Search results
        searchResults.when(
          data: (results) {
            if (_searchController.text.isEmpty) {
              return const SizedBox.shrink();
            }

            if (results.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(NovaSpacing.m),
                child: Text(
                  'Nessun risultato',
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(top: NovaSpacing.s),
              decoration: BoxDecoration(
                color: NovaColors.card(context),
                borderRadius: BorderRadius.circular(NovaRadius.s),
                border: Border.all(
                  color: NovaColors.border(context),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: NovaColors.divider(context),
                ),
                itemBuilder: (context, index) {
                  final user = results[index];
                  final isSelected =
                      widget.selectedUsers.any((u) => u.id == user.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: NovaColors.primary(context),
                      foregroundColor: Colors.white,
                      child: Text(
                        user.initials,
                        style: NovaTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user.fullName,
                      style: NovaTextStyles.body.copyWith(
                        color: NovaColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      user.classYear ?? '',
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: NovaColors.primary(context),
                          )
                        : null,
                    onTap: isSelected ? null : () => _addUser(user),
                    enabled: !isSelected,
                  );
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(NovaSpacing.m),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(NovaSpacing.m),
            child: Text(
              'Errore durante la ricerca',
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

/// User chip widget for selected co-organizers
class _UserChip extends StatelessWidget {
  final Profile user;
  final VoidCallback onRemove;

  const _UserChip({
    required this.user,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: NovaColors.primary(context),
        foregroundColor: Colors.white,
        child: Text(
          user.initials,
          style: NovaTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(
        user.fullName,
        style: NovaTextStyles.caption.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: 18,
        color: NovaColors.textSecondary(context),
      ),
      onDeleted: onRemove,
      backgroundColor: NovaColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.xs),
        side: BorderSide(
          color: NovaColors.border(context),
        ),
      ),
    );
  }
}
