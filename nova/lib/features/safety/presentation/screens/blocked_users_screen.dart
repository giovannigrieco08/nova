import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_block.dart';
import '../providers/block_provider.dart';

/// Screen showing list of blocked users with unblock option
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  /// Route name for navigation
  static const String routeName = '/blocked-users';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsers = ref.watch(blockedUsersProvider);
    final blockState = ref.watch(blockNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utenti bloccati'),
      ),
      body: blockedUsers.when(
        data: (users) {
          if (users.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(blockedUsersProvider.future),
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final block = users[index];
                return BlockedUserTile(
                  block: block,
                  isLoading: blockState.isLoading &&
                      blockState.lastUnblockedUserId == block.blockedId,
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Errore nel caricamento',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(blockedUsersProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Nessun utente bloccato',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Quando blocchi qualcuno, apparirà qui.\nPotrai sbloccarlo in qualsiasi momento.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile displaying a blocked user with unblock option
class BlockedUserTile extends ConsumerWidget {
  const BlockedUserTile({
    super.key,
    required this.block,
    this.isLoading = false,
  });

  final UserBlock block;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = block.blockedUser;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage:
            user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
        child: user?.avatarUrl == null
            ? Text(
                (user?.fullName ?? '?')[0].toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onSurface),
              )
            : null,
      ),
      title: Text(
        user?.fullName ?? 'Utente sconosciuto',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user?.username != null)
            Text(
              '@${user!.username}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          Text(
            'Bloccato ${_formatDate(block.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => _showUnblockConfirmation(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Sblocca'),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'oggi';
    } else if (diff.inDays == 1) {
      return 'ieri';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} giorni fa';
    } else if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return '$weeks settiman${weeks == 1 ? 'a' : 'e'} fa';
    } else {
      final months = diff.inDays ~/ 30;
      return '$months mes${months == 1 ? 'e' : 'i'} fa';
    }
  }

  void _showUnblockConfirmation(BuildContext context, WidgetRef ref) {
    final userName = block.blockedUser?.fullName ?? 'questo utente';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sblocca utente'),
        content: Text(
          'Vuoi sbloccare $userName?\n\n'
          'Dopo lo sblocco:\n'
          '• Potrai vedere i suoi contenuti\n'
          '• Potrà inviarti messaggi\n'
          '• Potrà vedere il tuo profilo',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await ref
                  .read(blockNotifierProvider.notifier)
                  .unblockUser(block.blockedId);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$userName è stato sbloccato'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Sblocca'),
          ),
        ],
      ),
    );
  }
}
