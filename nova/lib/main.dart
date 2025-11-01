// =====================================================================
// Nova - Main Application Entry Point
// =====================================================================
// Purpose: Initialize app, setup Supabase, and handle auth routing
// Architecture: Riverpod for state management, MaterialApp with auth guard
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/config/supabase_config.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/core/services/deep_link_service.dart';
import 'package:nova/core/widgets/splash_screen.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/features/auth/presentation/screens/login_screen.dart';
import 'package:nova/features/events/presentation/screens/main_feed_screen.dart';

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase BEFORE runApp
  await SupabaseConfig.initialize();

  runApp(
    // ProviderScope wraps entire app for Riverpod
    const ProviderScope(
      child: NovaApp(),
    ),
  );
}

/// Main application widget with auth routing and deep link handling
class NovaApp extends ConsumerStatefulWidget {
  const NovaApp({super.key});

  @override
  ConsumerState<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends ConsumerState<NovaApp> {
  // Deep link service instance
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  /// Initialize deep link handling
  Future<void> _initializeDeepLinks() async {
    await _deepLinkService.initialize(
      onLink: (uri) async {
        assert(() {
          debugPrint('🔗 Processing deep link: $uri');
          return true;
        }());

        // Check if this is an auth callback (magic link)
        if (uri.scheme == 'novaapp' &&
            uri.host == 'auth' &&
            uri.path == '/callback') {
          // Verify magic link token via auth notifier
          final success = await ref
              .read(authNotifierProvider.notifier)
              .verifyMagicLink(uri);

          if (success) {
            assert(() {
              debugPrint('✅ Magic link verified via deep link');
              return true;
            }());
            // Navigation handled automatically by AuthGuard
            // when auth state changes to AuthStateAuthenticated
          } else {
            assert(() {
              debugPrint('❌ Magic link verification failed');
              return true;
            }());
          }
        } else {
          assert(() {
            debugPrint('⚠️ Unknown deep link: $uri');
            return true;
          }());
        }
      },
    );
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova - School Events Platform',
      debugShowCheckedModeBanner: false,

      // Theme configuration from AppTheme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Auto follow OS theme

      // Splash screen shown first, then navigates to AuthGuard
      home: const SplashScreen(),
    );
  }
}

/// Auth guard widget that routes based on authentication state
///
/// Routes:
/// - LoginScreen: User not authenticated
/// - MainFeedScreen: User authenticated
/// - LoadingScreen: Auth state loading
/// - ErrorScreen: Auth error occurred
class AuthGuard extends ConsumerWidget {
  const AuthGuard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state from provider
    final authState = ref.watch(authNotifierProvider);

    // Route based on auth state
    return authState.when(
      // Data loaded - check auth state
      data: (state) {
        return switch (state) {
          // User authenticated - show main feed
          AuthStateAuthenticated() => const MainFeedScreen(),

          // User not authenticated - show login
          AuthStateUnauthenticated() => const LoginScreen(),

          // Loading state (shouldn't happen in data, but handle it)
          AuthStateLoading() => const _LoadingScreen(),

          // Error state (shouldn't happen in data, but handle it)
          AuthStateError(:final message) => _ErrorScreen(message: message),
        };
      },

      // Loading state - show loading screen
      loading: () => const _LoadingScreen(),

      // Error state - show error screen
      error: (error, stackTrace) => _ErrorScreen(
        message: error.toString(),
      ),
    );
  }
}

/// Loading screen shown during auth initialization
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Error screen shown when auth initialization fails
class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Authentication Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
