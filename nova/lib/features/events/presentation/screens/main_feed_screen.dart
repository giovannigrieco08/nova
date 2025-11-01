// =====================================================================
// Nova - Main Feed Screen (MVP Version - Placeholder)
// =====================================================================
// Purpose: Placeholder screen after successful authentication
// Architecture: Stateless widget with Riverpod integration
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/core/models/auth_state.dart';

/// Main feed screen - shown after successful authentication
///
/// This is a placeholder screen for the MVP.
/// Future implementation will include:
/// - List of upcoming school events
/// - Event filters and search
/// - Event details view
/// - User preferences
class MainFeedScreen extends ConsumerWidget {
  const MainFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // Get authenticated user
    final user = authState.when(
      data: (state) => switch (state) {
        AuthStateAuthenticated(:final user) => user,
        _ => null,
      },
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova'),
        actions: [
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleSignOut(context, ref),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome section
                const Icon(
                  Icons.celebration_rounded,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),

                Text(
                  'Welcome to Nova!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                if (user?.email != null) ...[
                  Text(
                    'Signed in as:',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user!.email!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 40),

                // Success message
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Authentication Working!',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Magic link authentication has been successfully implemented.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Coming soon section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coming Soon',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                          Icons.event_rounded,
                          'Browse school events',
                        ),
                        _buildFeatureItem(
                          Icons.search_rounded,
                          'Search and filter events',
                        ),
                        _buildFeatureItem(
                          Icons.bookmark_rounded,
                          'Save favorite events',
                        ),
                        _buildFeatureItem(
                          Icons.notifications_rounded,
                          'Get event reminders',
                        ),
                        _buildFeatureItem(
                          Icons.people_rounded,
                          'See who\'s attending',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build feature item
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  /// Handle sign out button press
  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Sign out via auth notifier
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}
