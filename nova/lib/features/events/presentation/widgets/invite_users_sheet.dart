// Widget: InviteUsersSheet
// Feature: Event Invitations
// Purpose: Sheet to search and invite users to an event

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/providers/core_providers.dart';
import '../providers/events_feed_provider.dart';

class InviteUsersSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const InviteUsersSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<InviteUsersSheet> createState() => _InviteUsersSheetState();
}

class _InviteUsersSheetState extends ConsumerState<InviteUsersSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _invitedUserIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final repository = ref.read(eventsRepositoryProvider);

      // Load already invited users
      final invitations = await repository.getEventInvitations(widget.eventId);
      _invitedUserIds =
          invitations.map((i) => i['invitee_id'] as String).toSet();

      // Load initial users (empty query shows some suggestions)
      final users = await repository.searchUsersToInvite(
        eventId: widget.eventId,
        currentUserId: userId,
        query: '',
      );

      setState(() {
        _searchResults = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query == _searchQuery) return;
    _searchQuery = query;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final repository = ref.read(eventsRepositoryProvider);
      final users = await repository.searchUsersToInvite(
        eventId: widget.eventId,
        currentUserId: userId,
        query: query,
      );

      if (_searchQuery == query) {
        setState(() {
          _searchResults = users;
        });
      }
    } catch (e) {
      // Search failed silently
    }
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = user['user_id'] as String;
    final userName = user['full_name'] as String? ?? 'Utente';

    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final repository = ref.read(eventsRepositoryProvider);
      await repository.inviteUser(
        eventId: widget.eventId,
        inviterId: currentUserId,
        inviteeId: userId,
      );

      setState(() {
        _invitedUserIds.add(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invito inviato a $userName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('duplicate')
                  ? 'Utente già invitato'
                  : 'Errore nell\'invio dell\'invito',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.handleBar,
              borderRadius: NovaRadius.circularXxs,
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Invita amici',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca per nome...',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: NovaColors.grayDark,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: NovaColors.grayDark,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: NovaRadius.circularXs,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: NovaColors.grayLight,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              onChanged: (query) {
                setState(() {});
                _searchUsers(query);
              },
            ),
          ),
          // Results
          Expanded(
            child: _buildContent(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: NovaColors.handleBar,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nessun utente trovato'
                  : 'Cerca utenti da invitare',
              style: const TextStyle(
                fontSize: 16,
                color: NovaColors.grayDark,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = user['user_id'] as String;
        final name = user['full_name'] as String? ?? '';
        final className = user['class'] as String? ?? '';
        final avatarUrl = user['avatar_url'] as String?;
        final isInvited = _invitedUserIds.contains(userId);

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: NovaColors.brandViolet.withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: NovaColors.brandViolet,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          subtitle: className.isNotEmpty
              ? Text(
                  className,
                  style: const TextStyle(
                    fontSize: 14,
                    color: NovaColors.grayDark,
                  ),
                )
              : null,
          trailing: isInvited
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: NovaColors.grayLight,
                    borderRadius: NovaRadius.circularXxs,
                  ),
                  child: const Text(
                    'Invitato',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.grayDark,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => _inviteUser(user),
                  style: TextButton.styleFrom(
                    backgroundColor: NovaColors.brandViolet,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: NovaRadius.circularXxs,
                    ),
                  ),
                  child: const Text(
                    'Invita',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
