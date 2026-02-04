// =====================================================================
// Nova - Main Application Entry Point
// =====================================================================
// Purpose: Initialize app, setup Supabase, and handle auth routing
// Architecture: Riverpod for state management, MaterialApp with auth guard
// =====================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nova/core/config/supabase_config.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/cupertino_theme.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/utils/deep_link_handler.dart';
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/core/services/deep_link_service.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/features/auth/presentation/screens/login_screen.dart';
import 'package:nova/features/events/presentation/screens/main_feed_screen.dart';
import 'package:nova/features/events/presentation/screens/event_detail_screen.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';
import 'package:nova/features/profile/presentation/providers/profile_provider.dart';
import 'package:nova/features/profile/presentation/providers/incomplete_profile_provider.dart';
import 'package:nova/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:nova/features/profile/presentation/screens/other_profile_screen.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/data/models/event_draft.dart';
import 'package:nova/features/events/data/models/comment_model.dart';
import 'package:nova/features/events/data/models/like_model.dart';
import 'package:nova/core/animations/page_transitions.dart';
import 'package:nova/features/events/data/models/participation_model.dart';
import 'package:nova/features/events/data/models/report_model.dart';
import 'package:nova/features/events/domain/entities/offline_action.dart';
import 'package:nova/features/search/data/models/search_results_cache.dart';

/// Firebase Cloud Messaging background message handler
/// Must be top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();

  // Background message handling logic will be added in Phase 4 (US2)
  // For now, just log the message
}

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [INIT] Flutter binding initialized');

  // Lock screen orientation to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  debugPrint('🚀 [INIT] Screen orientation locked');

  // Initialize Italian locale for date formatting
  await initializeDateFormatting('it_IT', null);
  debugPrint('🚀 [INIT] Date formatting initialized');

  // Initialize Firebase (for FCM push notifications)
  debugPrint('🚀 [INIT] Starting Firebase...');
  await Firebase.initializeApp();
  debugPrint('🚀 [INIT] Firebase initialized');

  // Configure FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('🚀 [INIT] FCM handler configured');

  // Initialize Supabase BEFORE runApp
  debugPrint('🚀 [INIT] Starting Supabase...');
  await SupabaseConfig.initialize();
  debugPrint('🚀 [INIT] Supabase initialized');

  // Initialize Hive for offline-first storage (profiles + events)
  debugPrint('🚀 [INIT] Starting Hive...');
  await Hive.initFlutter();
  debugPrint('🚀 [INIT] Hive initialized');

  // Register adapters (with error handling for hot reload/restart)
  // TypeIds must match @HiveType(typeId: X) in each model:
  // ProfileModel=1, EventModel=2, OfflineAction=3, CommentModel=4,
  // LikeModel=5, ParticipationModel=6, ReportModel=7, EventDraft=8,
  // SearchResultsCache=11, CachedEventResult=12, CachedProfileResult=13
  try {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProfileModelAdapter());
    }
  } catch (e) {
    // ProfileModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(EventModelAdapter());
    }
  } catch (e) {
    // EventModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(OfflineActionAdapter());
    }
  } catch (e) {
    // OfflineActionAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CommentModelAdapter());
    }
  } catch (e) {
    // CommentModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(LikeModelAdapter());
    }
  } catch (e) {
    // LikeModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ParticipationModelAdapter());
    }
  } catch (e) {
    // ParticipationModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReportModelAdapter());
    }
  } catch (e) {
    // ReportModelAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(EventDraftAdapter()); // Feature 004: Event drafts
    }
  } catch (e) {
    // EventDraftAdapter already registered
  }

  // Search results cache adapters (TypeIds: 11, 12, 13)
  try {
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(SearchResultsCacheAdapter());
    }
  } catch (e) {
    // SearchResultsCacheAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(CachedEventResultAdapter());
    }
  } catch (e) {
    // CachedEventResultAdapter already registered
  }

  try {
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(CachedProfileResultAdapter());
    }
  } catch (e) {
    // CachedProfileResultAdapter already registered
  }

  debugPrint('🚀 [INIT] Opening Hive boxes...');
  await Hive.openBox<ProfileModel>('profiles');
  debugPrint('🚀 [INIT] profiles box opened');
  await Hive.openBox<EventModel>('events_cache');
  debugPrint('🚀 [INIT] events_cache box opened');
  await Hive.openBox<EventDraft>(
      'event_drafts'); // Feature 004: Event creation drafts
  debugPrint('🚀 [INIT] event_drafts box opened');
  await Hive.openBox<OfflineAction>('offline_actions_queue');
  debugPrint('🚀 [INIT] offline_actions_queue box opened');
  await Hive.openBox<Map<dynamic, dynamic>>(
      'chat_pending_messages'); // Feature 011: Chat offline queue
  debugPrint('🚀 [INIT] chat_pending_messages box opened');

  // Initialize SharedPreferences for banner dismissal state
  debugPrint('🚀 [INIT] Getting SharedPreferences...');
  final prefs = await SharedPreferences.getInstance();
  debugPrint('🚀 [INIT] SharedPreferences ready');

  debugPrint('🚀 [INIT] Starting runApp...');
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
        // Note: pendingMessagesBoxProvider now uses Hive.box() directly
        // which works because the box is opened above before runApp()
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
  final _deepLinkHandler = DeepLinkHandler();

  // Global navigator key for deep link navigation
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  /// Initialize deep link handling
  Future<void> _initializeDeepLinks() async {
    await _deepLinkService.initialize(
      onLink: (uri) async {
        // Check if this is an auth callback (magic link)
        if (uri.scheme == 'novaapp' && uri.host == 'auth') {
          // Ensure we're still mounted
          if (!mounted) return;

          // Process magic link - the auth repository now handles
          // PKCE flow properly by checking existing sessions first
          final success = await ref
              .read(authNotifierProvider.notifier)
              .verifyMagicLink(uri);

          // Force refresh auth state to trigger AuthGuard rebuild
          if (success && mounted) {
            // Invalidate profile provider to ensure fresh data
            ref.invalidate(currentProfileProvider);

            // Force a frame rebuild to ensure UI updates
            if (mounted) {
              setState(() {});
            }
          }
        } else {
          // Try parsing as Nova event/profile deep link (nova://events/{id})
          final deepLinkInfo = _deepLinkHandler.parse(uri);

          if (deepLinkInfo != null) {
            // Handle based on deep link type
            switch (deepLinkInfo.type) {
              case DeepLinkType.event:
                // Navigate to event detail screen
                // Wait a bit for app initialization to complete
                await Future.delayed(const Duration(milliseconds: 500));

                // Navigate to EventDetailScreen with eventId
                if (_navigatorKey.currentState != null) {
                  _navigatorKey.currentState!.push(
                    NovaPageRoute.swipeBack(
                      page: EventDetailScreen(eventId: deepLinkInfo.eventId),
                    ),
                  );
                }
                break;

              case DeepLinkType.profile:
                // Navigate to profile screen
                // Wait a bit for app initialization to complete
                await Future.delayed(const Duration(milliseconds: 500));

                // Navigate to OtherProfileScreen with userId
                if (_navigatorKey.currentState != null) {
                  _navigatorKey.currentState!.push(
                    NovaPageRoute.swipeBack(
                      page: OtherProfileScreen(userId: deepLinkInfo.userId!),
                    ),
                  );
                }
                break;
            }
          }
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
    // Platform-adaptive app wrapper - always use light theme
    if (PlatformUtils.isIOS) {
      // iOS: CupertinoApp with light theme only
      return CupertinoApp(
        title: 'Nova',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey, // For deep link navigation

        // Always use light theme
        theme: NovaCupertinoTheme.light,

        home: const AuthGuard(),

        // Material localizations for compatibility
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      );
    }

    // Android: MaterialApp with light theme only
    return MaterialApp(
      title: 'Nova - School Events Platform',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey, // For deep link navigation

      // Always use light theme
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,

      home: const AuthGuard(),
    );
  }
}

// =============================================================================
// ⚠️ DEV BYPASS - REMOVE BEFORE PRODUCTION! ⚠️
// =============================================================================
// Set to true to bypass authentication and go directly to main app.
// Requires a valid existing Supabase session (login once manually first).
// This is ONLY for development testing. MUST be set to false before release!
// =============================================================================
const bool kDevBypassAuth = false;
const String kDevUserEmail = 'griecogiovanni08@gmail.com';
// =============================================================================

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
    // ⚠️ DEV BYPASS - Skip auth check in development
    if (kDevBypassAuth) {
      // In dev mode, try to get user from Supabase directly
      final devUser = ref.read(supabaseClientProvider).auth.currentUser;
      return _ProfileCheckGuard(userId: devUser?.id);
    }

    // Watch auth state from provider
    final authState = ref.watch(authNotifierProvider);

    // Route based on auth state
    return authState.when(
      // Data loaded - check auth state
      data: (state) {
        return switch (state) {
          // User authenticated - pass user ID to profile guard
          // This ensures the ID is available immediately after magic link verification
          AuthStateAuthenticated(:final user) =>
            _ProfileCheckGuard(userId: user.id),

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
///
/// The [userId] is passed from [AuthGuard] to avoid race conditions where
/// Supabase's internal session might not be synchronized yet after magic link
/// verification.
class _ProfileCheckGuard extends ConsumerWidget {
  const _ProfileCheckGuard({required this.userId});

  /// User ID from authenticated state (passed from AuthGuard)
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If no user ID, return to login (shouldn't happen after AuthStateAuthenticated)
    if (userId == null) {
      // ⚠️ DEV MODE: Show helpful message if no session exists
      if (kDevBypassAuth) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 64, color: NovaColors.warningLight),
                  const SizedBox(height: 16),
                  const Text(
                    'DEV MODE: No Session',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Devi prima effettuare il login una volta con:\n$kDevUserEmail\n\nPoi il bypass funzionerà automaticamente.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to login
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Vai al Login'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const LoginScreen();
    }

    // Watch profile for current user
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      // Profile loaded successfully - always show main feed
      // Profile completeness is handled by prompts within the app, not blocking
      data: (profile) => const MainFeedScreen(),

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
/// Uses same splash screen style for seamless experience
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    // Simple loading indicator for debugging
    return const Scaffold(
      backgroundColor: NovaColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: NovaColors.primaryLight,
            ),
            SizedBox(height: 16),
            Text(
              'Caricamento...',
              style: TextStyle(
                color: NovaColors.textPrimaryLight,
                fontSize: 16,
              ),
            ),
          ],
        ),
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
                color: NovaColors.errorLight,
              ),
              const SizedBox(height: 16),
              const Text(
                'Authentication Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
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
