// =====================================================================
// Nova - Main Application Entry Point
// =====================================================================
// Purpose: Initialize app, setup Supabase, and handle auth routing
// Architecture: Riverpod for state management, MaterialApp with auth guard
// =====================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nova/core/config/supabase_config.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/core/theme/cupertino_theme.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/core/services/deep_link_service.dart';
import 'package:nova/core/widgets/splash_screen.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/features/auth/presentation/screens/login_screen.dart';
import 'package:nova/features/events/presentation/screens/main_feed_screen.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import 'package:nova/features/profile/presentation/providers/profile_provider.dart';
import 'package:nova/features/profile/presentation/providers/incomplete_profile_provider.dart';
import 'package:nova/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/data/models/event_draft.dart';
import 'package:nova/features/events/data/models/comment_model.dart';
import 'package:nova/features/events/data/models/like_model.dart';
import 'package:nova/features/events/data/models/participation_model.dart';
import 'package:nova/features/events/data/models/report_model.dart';
import 'package:nova/features/events/domain/entities/offline_action.dart';

/// Firebase Cloud Messaging background message handler
/// Must be top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();

  // Handle background notification
  assert(() {
    debugPrint('🔔 Handling background FCM message: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    return true;
  }());

  // Background message handling logic will be added in Phase 4 (US2)
  // For now, just log the message
}

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (for FCM push notifications)
  await Firebase.initializeApp();

  // Configure FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Supabase BEFORE runApp
  await SupabaseConfig.initialize();

  // Initialize Hive for offline-first storage (profiles + events)
  await Hive.initFlutter();
  Hive.registerAdapter(ProfileModelAdapter());
  Hive.registerAdapter(EventModelAdapter());
  Hive.registerAdapter(EventDraftAdapter()); // Feature 004: Event drafts
  Hive.registerAdapter(CommentModelAdapter());
  Hive.registerAdapter(LikeModelAdapter());
  Hive.registerAdapter(ParticipationModelAdapter());
  Hive.registerAdapter(ReportModelAdapter());
  Hive.registerAdapter(OfflineActionAdapter());
  await Hive.openBox<ProfileModel>('profiles');
  await Hive.openBox<EventModel>('events_cache');
  await Hive.openBox<EventDraft>('event_drafts'); // Feature 004: Event creation drafts
  await Hive.openBox<OfflineAction>('offline_actions_queue');

  // Initialize SharedPreferences for banner dismissal state
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // ProviderScope wraps entire app for Riverpod with profile overrides
    ProviderScope(
      overrides: [
        // Override Hive box provider with opened box
        profileBoxProvider.overrideWithValue(
          Hive.box<ProfileModel>('profiles'),
        ),
        // Override SharedPreferences provider with instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NovaApp(),
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
    // Platform-adaptive app wrapper
    if (PlatformUtils.isIOS) {
      // iOS: CupertinoApp with native theme
      return CupertinoApp(
        title: 'Nova',
        debugShowCheckedModeBanner: false,

        // Cupertino theme configuration (cached themes)
        theme: NovaCupertinoTheme.light,

        // Splash screen shown first, then navigates to AuthGuard
        home: const SplashScreen(),

        // Material localizations for compatibility
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      );
    }

    // Android: MaterialApp with Material 3 theme
    return MaterialApp(
      title: 'Nova - School Events Platform',
      debugShowCheckedModeBanner: false,

      // Material 3 theme configuration
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
          // User authenticated - check profile before routing
          AuthStateAuthenticated() => const _ProfileCheckGuard(),

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

/// Profile check guard - routes to setup or main feed based on profile status
///
/// Routes:
/// - ProfileSetupScreen: Profile doesn't exist or is incomplete (class is null)
/// - MainFeedScreen: Profile exists and is complete
class _ProfileCheckGuard extends ConsumerWidget {
  const _ProfileCheckGuard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user ID
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    // If no user ID, return to login (shouldn't happen after AuthStateAuthenticated)
    if (userId == null) {
      return const LoginScreen();
    }

    // Watch profile for current user
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      // Profile loaded successfully
      data: (profile) {
        // Check if profile is complete (has class selected)
        if (profile.isComplete) {
          // Profile complete - show main feed
          return const MainFeedScreen();
        } else {
          // Profile incomplete (class is null) - show setup to complete
          return const ProfileSetupScreen();
        }
      },

      // Loading profile
      loading: () => const _LoadingScreen(),

      // Error loading profile (likely profile doesn't exist yet)
      error: (error, stackTrace) {
        // Profile doesn't exist - show setup screen to create it
        return const ProfileSetupScreen();
      },
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
