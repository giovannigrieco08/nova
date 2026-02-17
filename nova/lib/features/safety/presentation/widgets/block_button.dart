import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_provider.dart';

/// A button/menu item for blocking users
class BlockButton extends ConsumerWidget {
  const BlockButton({
    super.key,
    required this.userId,
    required this.userName,
    this.onBlocked,
    this.iconOnly = false,
  });

  final String userId;
  final String userName;
  final VoidCallback? onBlocked;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = ref.watch(isUserBlockedProvider(userId));
    final blockState = ref.watch(blockNotifierProvider);

    return isBlocked.when(
      data: (blocked) {
        if (blocked) {
          return _buildUnblockButton(context, ref);
        }
        return _buildBlockButton(context, ref, blockState.isLoading);
      },
      loading: () => _buildLoadingState(context),
      error: (_, __) => _buildBlockButton(context, ref, false),
    );
  }

  Widget _buildBlockButton(
      BuildContext context, WidgetRef ref, bool isLoading) {
    final theme = Theme.of(context);

    if (iconOnly) {
      return IconButton(
        icon: Icon(
          Icons.block,
          color: theme.colorScheme.error,
        ),
        onPressed:
            isLoading ? null : () => _showBlockConfirmation(context, ref),
        tooltip: 'Blocca utente',
      );
    }

    return TextButton.icon(
      onPressed: isLoading ? null : () => _showBlockConfirmation(context, ref),
      icon: Icon(
        Icons.block,
        size: 18,
        color: theme.colorScheme.error,
      ),
      label: Text(
        'Blocca',
        style: TextStyle(color: theme.colorScheme.error),
      ),
    );
  }

  Widget _buildUnblockButton(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (iconOnly) {
      return IconButton(
        icon: Icon(
          Icons.block,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        onPressed: null,
        tooltip: 'Utente bloccato',
      );
    }

    return TextButton.icon(
      onPressed: null,
      icon: Icon(
        Icons.block,
        size: 18,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
      label: Text(
        'Bloccato',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    if (iconOnly) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: null,
      icon: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: const Text('...'),
    );
  }

  void _showBlockConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => BlockConfirmationDialog(
        userId: userId,
        userName: userName,
        onConfirm: () async {
          Navigator.of(context).pop();
          final success =
              await ref.read(blockNotifierProvider.notifier).blockUser(userId);
          if (success && context.mounted) {
            onBlocked?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$userName è stato bloccato'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}

/// Confirmation dialog for blocking a user
class BlockConfirmationDialog extends StatelessWidget {
  const BlockConfirmationDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.onConfirm,
  });

  final String userId;
  final String userName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.block, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          const Text('Blocca utente'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vuoi bloccare $userName?'),
          const SizedBox(height: 16),
          Text(
            'Cosa succede quando blocchi qualcuno:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildBulletPoint(context, 'Non vedrai più i suoi contenuti'),
          _buildBulletPoint(context, 'Non potrà inviarti messaggi'),
          _buildBulletPoint(context, 'Non potrà vedere il tuo profilo'),
          _buildBulletPoint(context, 'Non riceverà notifica del blocco'),
          const SizedBox(height: 12),
          Text(
            'Potrai sbloccare in qualsiasi momento dalle impostazioni.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Blocca'),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu item for use in popup menus
class BlockMenuItem extends ConsumerWidget {
  const BlockMenuItem({
    super.key,
    required this.userId,
    required this.userName,
    this.onBlocked,
  });

  final String userId;
  final String userName;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = ref.watch(isUserBlockedProvider(userId));
    final theme = Theme.of(context);

    final blocked = isBlocked.valueOrNull ?? false;
    final isLoading = isBlocked.isLoading;

    return PopupMenuItem<void>(
      enabled: !blocked && !isLoading,
      onTap: () {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => BlockConfirmationDialog(
                userId: userId,
                userName: userName,
                onConfirm: () async {
                  Navigator.of(context).pop();
                  final success = await ref
                      .read(blockNotifierProvider.notifier)
                      .blockUser(userId);
                  if (success && context.mounted) {
                    onBlocked?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$userName è stato bloccato'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            );
          }
        });
      },
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: blocked
                ? theme.colorScheme.onSurface.withOpacity(0.5)
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Text(
            blocked ? 'Bloccato' : 'Blocca',
            style: TextStyle(
              color: blocked
                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// ListTile for use in bottom sheets
class BlockListTile extends ConsumerWidget {
  const BlockListTile({
    super.key,
    required this.userId,
    required this.userName,
    this.onBlocked,
  });

  final String userId;
  final String userName;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = ref.watch(isUserBlockedProvider(userId));
    final theme = Theme.of(context);

    final blocked = isBlocked.valueOrNull ?? false;
    final isLoading = isBlocked.isLoading;

    return ListTile(
      enabled: !blocked && !isLoading,
      leading: Icon(
        Icons.block,
        color: blocked
            ? theme.colorScheme.onSurface.withOpacity(0.5)
            : theme.colorScheme.error,
      ),
      title: Text(
        blocked ? 'Utente bloccato' : 'Blocca utente',
        style: TextStyle(
          color: blocked
              ? theme.colorScheme.onSurface.withOpacity(0.5)
              : theme.colorScheme.error,
        ),
      ),
      subtitle: blocked
          ? null
          : Text(
              'Non vedrai più i suoi contenuti',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
      onTap: blocked || isLoading
          ? null
          : () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => BlockConfirmationDialog(
                  userId: userId,
                  userName: userName,
                  onConfirm: () async {
                    Navigator.of(context).pop();
                    final success = await ref
                        .read(blockNotifierProvider.notifier)
                        .blockUser(userId);
                    if (success && context.mounted) {
                      onBlocked?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$userName è stato bloccato'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              );
            },
    );
  }
}
