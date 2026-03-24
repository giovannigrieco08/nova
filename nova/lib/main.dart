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
import 'package:nova/features/auth/presentation/screens/guest_feed_screen.dart';
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
import 'package:nova/core/widgets/nova_logo.dart';
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
  try {
    await initializeDateFormatting('it_IT', null);
    debugPrint('🚀 [INIT] Date formatting initialized');
  } catch (e) {
    debugPrint('🚀 [INIT] Date formatting failed (using default): $e');
  }

  // Initialize Firebase (for FCM push notifications)
  debugPrint('🚀 [INIT] Starting Firebase...');
  try {
    await Firebase.initializeApp();
    debugPrint('🚀 [INIT] Firebase initialized');
  } catch (e) {
    debugPrint('🚀 [INIT] Firebase initialization failed: $e');
    // Continue without Firebase - push notifications won't work but app can run
  }

  // Configure FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('🚀 [INIT] FCM handler configured');

  // Initialize Supabase BEFORE runApp
  debugPrint('🚀 [INIT] Starting Supabase...');
  await SupabaseConfig.initialize();
  debugPrint('🚀 [INIT] Supabase initialized');

  // Initialize Hive for offline-first storage (profiles + events)
  debugPrint('🚀 [INIT] Starting Hive...');
  try {
    await Hive.initFlutter();
    debugPrint('🚀 [INIT] Hive initialized');
  } catch (e) {
    debugPrint('🚀 [INIT] Hive initialization failed: $e');
    // Continue - offline storage won't work but app can run online-only
  }

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

class _NovaAppState extends ConsumerState<NovaApp> with WidgetsBindingObserver {
  // Deep link service instance
  final _deepLinkService = DeepLinkService();
  final _deepLinkHandler = DeepLinkHandler();

  // Global navigator key for deep link navigation
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDeepLinks();
  }

  /// Initialize deep link handling
  Future<void> _initializeDeepLinks() async {
    await _deepLinkService.initialize(
      onLink: (uri) async {
        debugPrint('🔗 [DEEP_LINK] Received: $uri');
        debugPrint('🔗 [DEEP_LINK] Scheme: ${uri.scheme}, Host: ${uri.host}');

        // Check if this is an auth callback (magic link)
        // Support both custom scheme (novaapp://auth) and Universal Links (https://nova-app.shop/auth)
        final isCustomSchemeAuth = uri.scheme == 'novaapp' && uri.host == 'auth';
        final isUniversalLinkAuth = uri.scheme == 'https' &&
            uri.host == 'nova-app.shop' &&
            uri.path.startsWith('/auth');

        if (isCustomSchemeAuth || isUniversalLinkAuth) {
          debugPrint('🔗 [DEEP_LINK] Processing auth callback...');

          // Ensure we're still mounted
          if (!mounted) {
            debugPrint('🔗 [DEEP_LINK] Widget not mounted, skipping');
            return;
          }

          // Process magic link - the auth repository now handles
          // PKCE flow properly by waiting for the SDK to process the code
          final success = await ref
              .read(authNotifierProvider.notifier)
              .verifyMagicLink(uri);

          debugPrint('🔗 [DEEP_LINK] Verification result: $success');
          // The AuthGuard automatically watches authNotifierProvider and will
          // rebuild when the state changes. _ProfileCheckGuard will then
          // watch currentProfileProvider and load fresh data.
        } else {
          // Try parsing as Nova event/profile deep link (nova://events/{id})
          final deepLinkInfo = _deepLinkHandler.parse(uri);

          if (deepLinkInfo != null) {
            // Wait for navigator to be ready (with timeout)
            NavigatorState? navigator;
            for (var i = 0; i < 10 && navigator == null; i++) {
              navigator = _navigatorKey.currentState;
              if (navigator == null) {
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }

            if (navigator == null) {
              debugPrint('🔗 [DEEP_LINK] Navigator not ready after timeout');
              return;
            }

            // Handle based on deep link type
            switch (deepLinkInfo.type) {
              case DeepLinkType.event:
                navigator.push(
                  NovaPageRoute.swipeBack(
                    page: EventDetailScreen(eventId: deepLinkInfo.eventId),
                  ),
                );
                break;

              case DeepLinkType.profile:
                if (deepLinkInfo.userId != null) {
                  navigator.push(
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
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.dispose();
    super.dispose();
  }

  /// Handle app lifecycle changes to sync auth state on resume
  ///
  /// When the app resumes from background (after magic link click),
  /// Supabase PKCE may have already authenticated the user.
  /// This ensures the UI updates to reflect the authenticated state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 [LIFECYCLE] State changed to: $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 [LIFECYCLE] App resumed, checking auth state...');
      _checkAuthStateOnResume();
    }
  }

  /// Check if user was authenticated while app was in background
  ///
  /// This handles the case where:
  /// 1. User sends magic link and sees "email sent" screen
  /// 2. User clicks magic link in email app
  /// 3. Supabase PKCE processes authentication during redirect
  /// 4. App resumes but deep link callback wasn't received
  ///
  /// By checking the current session on resume, we ensure the Riverpod
  /// state is synced with Supabase. Since we now watch auth state
  /// directly in build(), any state change will trigger a rebuild.
  Future<void> _checkAuthStateOnResume() async {
    if (!mounted) return;

    // CRITICAL: Skip if a magic link is currently being processed
    // This prevents race conditions where we sync the OLD user while
    // the magic link for a NEW user is being processed
    final authNotifier = ref.read(authNotifierProvider.notifier);
    if (authNotifier.isProcessingMagicLink) {
      debugPrint('📱 [RESUME] Magic link processing in progress, skipping sync');
      return;
    }

    // Small delay to allow Supabase to restore session from storage
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Check again after delay - magic link might have started processing
    if (authNotifier.isProcessingMagicLink) {
      debugPrint('📱 [RESUME] Magic link processing started during delay, skipping sync');
      return;
    }

    // Check if Supabase has an authenticated session
    final supabase = ref.read(supabaseClientProvider);
    final currentUser = supabase.auth.currentUser;

    debugPrint('📱 [RESUME] Supabase currentUser: ${currentUser?.id}');

    if (currentUser != null) {
      // User is authenticated in Supabase - ensure Riverpod state is synced
      final currentAuthState = ref.read(authNotifierProvider);
      final needsSync = currentAuthState.maybeWhen(
        data: (state) =>
            state is AuthStateUnauthenticated || state is AuthStateGuest,
        orElse: () => false,
      );

      debugPrint('📱 [RESUME] Riverpod needs sync: $needsSync');

      if (needsSync) {
        // Supabase has a session but Riverpod doesn't know about it
        // Force a state update - this will trigger build() via ref.watch
        debugPrint('📱 [RESUME] Syncing auth state...');
        await ref.read(authNotifierProvider.notifier).verifyMagicLink(
              Uri.parse('novaapp://auth/resume'),
            );
      }
    } else {
      debugPrint('📱 [RESUME] No authenticated user found');
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Listen for auth state changes and navigate explicitly
    // Changing 'home' parameter on MaterialApp/CupertinoApp does NOT trigger
    // navigation when the app is already running - home is only the initial widget.
    // We must use Navigator to actually switch screens.
    ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (previous, next) {
      debugPrint('🧭 [NAV] Auth state changed: $previous → $next');

      final previousState = previous?.valueOrNull;
      final nextState = next.valueOrNull;

      // Navigate when transitioning from unauthenticated to authenticated
      if (previousState is AuthStateUnauthenticated &&
          nextState is AuthStateAuthenticated) {
        debugPrint('🧭 [NAV] 🎯 Navigating to ProfileCheckGuard!');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          // Use pushAndRemoveUntil to clear the navigation stack
          // and show the authenticated screen
          // Note: No ProviderScope needed - Navigator is inside the app's ProviderScope
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => _ProfileCheckGuard(userId: nextState.user.id),
            ),
            (route) => false, // Remove all previous routes
          );
        } else {
          debugPrint('🧭 [NAV] ⚠️ Navigator is null!');
        }
      }

      // Navigate when transitioning from guest to authenticated (login from guest mode)
      if (previousState is AuthStateGuest &&
          nextState is AuthStateAuthenticated) {
        debugPrint('🧭 [NAV] 🎯 Navigating to ProfileCheckGuard (from guest)!');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => _ProfileCheckGuard(userId: nextState.user.id),
            ),
            (route) => false,
          );
        }
      }

      // Navigate when transitioning from guest to unauthenticated (user taps sign in)
      if (previousState is AuthStateGuest &&
          nextState is AuthStateUnauthenticated) {
        debugPrint('🧭 [NAV] 🎯 Navigating to LoginScreen (from guest)');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      }

      // Navigate when transitioning from unauthenticated to guest (user taps continue browsing)
      if (previousState is AuthStateUnauthenticated &&
          nextState is AuthStateGuest) {
        debugPrint(
            '🧭 [NAV] 🎯 Navigating to GuestFeedScreen (continue browsing)');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const GuestFeedScreen(),
            ),
            (route) => false,
          );
        }
      }

      // Navigate when transitioning from authenticated to unauthenticated (logout)
      if (previousState is AuthStateAuthenticated &&
          nextState is AuthStateUnauthenticated) {
        debugPrint('🧭 [NAV] 🎯 Navigating to LoginScreen (logout)');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      }

      // Navigate when transitioning from authenticated to guest (logout to guest mode)
      if (previousState is AuthStateAuthenticated &&
          nextState is AuthStateGuest) {
        debugPrint(
            '🧭 [NAV] 🎯 Navigating to GuestFeedScreen (logout to guest)');
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const GuestFeedScreen(),
            ),
            (route) => false,
          );
        }
      }
    });

    // Watch auth state directly for initial widget determination
    final authState = ref.watch(authNotifierProvider);
    debugPrint('🏠 [NovaApp] build() authState: $authState');

    // Determine home widget based on auth state
    final Widget home = authState.when(
      data: (state) {
        debugPrint('🏠 [NovaApp] data state: $state');
        return switch (state) {
          AuthStateAuthenticated(:final user) => () {
              debugPrint('🏠 [NovaApp] → Showing ProfileCheckGuard');
              // Use ValueKey to force widget recreation when user changes
              return _ProfileCheckGuard(
                  key: ValueKey('profile_${user.id}'), userId: user.id);
            }(),
          AuthStateUnauthenticated() => () {
              debugPrint('🏠 [NovaApp] → Showing LoginScreen');
              return const LoginScreen();
            }(),
          // Apple Guideline 5.1.1: Guest mode - Instagram-style feed browsing
          AuthStateGuest() => () {
              debugPrint('🏠 [NovaApp] → Showing GuestFeedScreen');
              return const GuestFeedScreen();
            }(),
          AuthStateLoading() => const _LoadingScreen(),
          AuthStateError(:final message) => _ErrorScreen(message: message),
        };
      },
      loading: () {
        debugPrint('🏠 [NovaApp] → Showing LoadingScreen');
        return const _LoadingScreen();
      },
      error: (error, stackTrace) {
        debugPrint('🏠 [NovaApp] → Showing ErrorScreen: $error');
        return _ErrorScreen(message: error.toString());
      },
    );

    return _buildApp(home);
  }

  /// Build the platform-specific app with the given home widget
  Widget _buildApp(Widget home) {
    if (PlatformUtils.isIOS) {
      // iOS: CupertinoApp with light theme only
      return CupertinoApp(
        title: 'Nova',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: NovaCupertinoTheme.light,
        home: home,
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
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: home,
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
  const _ProfileCheckGuard({super.key, required this.userId});

  /// User ID from authenticated state (passed from AuthGuard)
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If no user ID, return to login (shouldn't happen after AuthStateAuthenticated)
    if (userId == null) {
      return const LoginScreen();
    }

    // Watch profile for current user
    final profileAsync = ref.watch(currentProfileProvider);
    debugPrint(
        '👤 [ProfileCheckGuard] build() userId: $userId, profileAsync: $profileAsync');

    return profileAsync.when(
      // Profile loaded successfully - always show main feed
      // Profile completeness is handled by prompts within the app, not blocking
      data: (profile) {
        debugPrint('👤 [ProfileCheckGuard] → Showing MainFeedScreen');
        return const MainFeedScreen();
      },

      // Loading profile
      loading: () {
        debugPrint(
            '👤 [ProfileCheckGuard] → Showing LoadingScreen (profile loading)');
        return const _LoadingScreen();
      },

      // Error loading profile (likely profile doesn't exist yet)
      error: (error, stackTrace) {
        debugPrint(
            '👤 [ProfileCheckGuard] → Showing ProfileSetupScreen (error: $error)');
        // Profile doesn't exist - show setup screen to create it
        return const ProfileSetupScreen();
      },
    );
  }
}

/// Loading screen shown during auth initialization
/// Matches native splash screen for seamless experience (no visible loading)
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    // Match native splash: black background with centered white Nova logo
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: NovaLogo.extraLarge(
          color: Colors.white,
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
