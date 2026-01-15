// =====================================================================
// Nova - Main Feed Screen (BeReal-Inspired Design)
// =====================================================================
// Purpose: Main screen with Eventi feed and bottom navigation
// Architecture: Custom NovaAppBar and NovaBottomNavBar
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/instagram_refresh_indicator.dart';
import '../../../../shared/widgets/nova_bottom_nav_bar.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../tutoring/presentation/screens/subjects_screen.dart';
import '../../../notifications/presentation/screens/notification_list_screen.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../notifications/presentation/providers/push_providers.dart';
import '../../../../shared/widgets/in_app_notification_banner.dart';
import '../providers/events_feed_provider.dart';
import 'events_feed_screen.dart';
import 'event_creation_screen.dart';
import 'event_detail_screen.dart';

/// Main feed screen with Eventi feed
///
/// Features:
/// - NovaAppBar with logo and notifications
/// - Eventi feed
/// - NovaBottomNavBar with pill-shaped glassmorphic design
/// - Clean white background (BeReal-inspired)
class MainFeedScreen extends ConsumerStatefulWidget {
  const MainFeedScreen({super.key});

  @override
  ConsumerState<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends ConsumerState<MainFeedScreen> {
  int _currentNavIndex = 0; // Bottom nav index (0=Home, 1=Search, 2=Tutoring, 3=Chat, 4=Profile)

  // Instagram-style refresh state
  bool _isRefreshing = false;
  // Use ValueNotifier to avoid setState on every scroll frame (60fps = 60 rebuilds/sec)
  final ValueNotifier<double> _pullProgressNotifier = ValueNotifier(0.0);

  // Swipe gesture tracking
  bool _isHorizontalDragActive = false;

  @override
  void initState() {
    super.initState();
    // Setup foreground notification banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupForegroundNotificationBanner();
    });
  }

  /// Setup foreground notification callback to show in-app banner
  void _setupForegroundNotificationBanner() {
    final pushService = ref.read(pushNotificationServiceProvider);
    pushService.onForegroundNotification = (payload) {
      if (!mounted) return;

      InAppNotificationBanner.show(
        context: context,
        title: payload.title ?? 'Nova',
        body: payload.body ?? '',
        onTap: () {
          // Navigate based on payload type
          final targetType = payload.targetType;
          final targetId = payload.targetId;

          if (targetType == 'event') {
            Navigator.push(
              context,
              NovaPageRoute.swipeBack(page: EventDetailScreen(eventId: targetId)),
            );
          } else if (targetType == 'chat') {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ChatScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          } else {
            // Default: go to notifications
            _onNotificationsTap();
          }
        },
      );
    };
  }

  @override
  void dispose() {
    // Clear the callback when disposing
    final pushService = ref.read(pushNotificationServiceProvider);
    pushService.onForegroundNotification = null;
    _pullProgressNotifier.dispose();
    super.dispose();
  }

  /// Handle bottom navigation item selection
  void _onNavItemSelected(int index) {
    // Chat (index 3) è l'unica schermata che viene pushata separatamente
    if (index == 3) {
      _openChatScreen();
      return;
    }

    // Tutte le altre schermate rimangono con la bottom navbar visibile
    setState(() {
      _currentNavIndex = index;
    });
  }

  /// Apre la Chat come schermata separata (senza bottom navbar)
  Future<void> _openChatScreen() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// Build navigation items (fixed 5 tabs for all users)
  List<NavItem> _buildNavItems() {
    // Get current user profile for avatar
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;

    return [
      const NavItem(
        sfSymbol: 'house.fill',
        materialIcon: Icons.home,
        label: 'Home',
      ),
      const NavItem(
        sfSymbol: 'magnifyingglass',
        materialIcon: Icons.search,
        label: 'Cerca',
      ),
      const NavItem(
        sfSymbol: 'book.fill',
        materialIcon: Icons.school,
        label: 'Ripetizioni',
      ),
      const NavItem(
        sfSymbol: 'message.fill',
        materialIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
      // Profile tab with user avatar (Instagram-style)
      NavItem(
        label: 'Profilo',
        customIcon: AvatarWidget(
          avatarUrl: profile?.avatarUrl,
          name: profile?.fullName ?? 'U',
          size: 28,
        ),
      ),
    ];
  }

  /// Handle create button tap - Open event/bacheca creation screen (slide from left)
  void _onCreateTap() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const EventCreationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide from left (starts off-screen left, slides to center)
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Build notification bell with unread badge
  Widget _buildNotificationBell(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          context.isIOS ? CupertinoIcons.bell : Icons.notifications_outlined,
          color: NovaColors.textPrimary(context),
          size: 24,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: NovaColors.error(context),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Handle notifications icon tap (slide from right)
  void _onNotificationsTap() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NotificationListScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide from right (starts off-screen right, slides to center)
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Handle horizontal swipe gestures on Home screen
  /// - Swipe left (right→left): Open notifications
  /// - Swipe right (left→right): Open event creation
  void _onHorizontalDragStart(DragStartDetails details) {
    _isHorizontalDragActive = true;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isHorizontalDragActive) return;
    _isHorizontalDragActive = false;

    final velocity = details.velocity.pixelsPerSecond.dx;

    // Minimum velocity threshold for swipe detection
    const minVelocity = 300.0;

    // Swipe left (right→left) with sufficient velocity → Notifications
    if (velocity < -minVelocity) {
      _onNotificationsTap();
      return;
    }

    // Swipe right (left→right) with sufficient velocity → Create event
    if (velocity > minVelocity) {
      _onCreateTap();
      return;
    }
  }

  void _onHorizontalDragCancel() {
    _isHorizontalDragActive = false;
  }

  /// Build the main content based on current nav index
  Widget _buildMainContent() {
    // Index 0: Home (Eventi/Bacheche con top navbar)
    // Index 1: Search
    // Index 2: Tutoring
    // Index 3: Chat (non usato qui, viene pushato separatamente)
    // Index 4: Profile

    return IndexedStack(
      index: _currentNavIndex > 3 ? _currentNavIndex - 1 : _currentNavIndex, // Skip Chat index
      children: [
        // 0: Home with Eventi/Bacheche tabs
        _buildHomeScreen(),
        // 1: Search
        const SearchScreen(),
        // 2: Tutoring
        const SubjectsScreen(),
        // 3: Profile (index 4 in navbar, but 3 in stack since Chat is skipped)
        const ProfileScreen(),
      ],
    );
  }

  /// Handle pull-to-refresh for events feed
  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await ref.read(eventsFeedProvider.notifier).refresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        _pullProgressNotifier.value = 0.0;
      }
    }
  }

  /// Handle scroll notifications for pull-to-refresh
  /// Uses ValueNotifier to avoid setState on every scroll frame
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;

      // Detect overscroll (negative pixels with BouncingScrollPhysics)
      if (pixels < 0) {
        // Calculate progress based on how far user pulled
        final progress = (-pixels / 100.0).clamp(0.0, 1.0);
        if (progress != _pullProgressNotifier.value) {
          _pullProgressNotifier.value = progress;
        }
      } else if (_pullProgressNotifier.value > 0 && pixels >= 0) {
        // Reset when scrolling back to normal position
        _pullProgressNotifier.value = 0.0;
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullProgressNotifier.value >= 1.0) {
        // Trigger refresh when pulled enough
        _onRefresh();
      } else if (_pullProgressNotifier.value > 0) {
        // Reset if not pulled enough
        _pullProgressNotifier.value = 0.0;
      }
    }

    return false;
  }

  /// Build the Home screen with Eventi feed
  Widget _buildHomeScreen() {
    return GestureDetector(
      // Horizontal swipe gestures for navigation
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      behavior: HitTestBehavior.translucent,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: NovaColors.background(context),
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 56,
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              title: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sinistra: Pulsante + (schermata slide da sinistra)
                    GestureDetector(
                      onTap: _onCreateTap,
                      child: Icon(
                        context.isIOS ? CupertinoIcons.plus : Icons.add,
                        color: NovaColors.textPrimary(context),
                        size: 24,
                      ),
                    ),

                    // Centro: Titolo "Eventi" (statico, senza dropdown)
                    Text(
                      'Eventi',
                      style: NovaTypography.headingMedium.copyWith(
                        color: NovaColors.textPrimary(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    // Destra: Campanella (schermata slide da destra)
                    GestureDetector(
                      onTap: _onNotificationsTap,
                      child: _buildNotificationBell(context),
                    ),
                  ],
                ),
              ),
            ),

            // Instagram-style refresh indicator (below header)
            // Use ValueListenableBuilder to only rebuild this widget, not entire screen
            SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: _pullProgressNotifier,
                builder: (context, pullProgress, _) {
                  if (!_isRefreshing && pullProgress == 0) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: InstagramRefreshIndicator(
                      size: 24,
                      isRefreshing: _isRefreshing,
                      pullProgress: pullProgress,
                    ),
                  );
                },
              ),
            ),
          ];
        },
        body: EventsFeedScreen(
          showAppBar: false,
          disableRefresh: true, // Disable built-in refresh since we handle it here
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _buildNavItems();

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: Stack(
        children: [
          // Main content (IndexedStack per mantenere lo stato delle schermate)
          _buildMainContent(),

          // Bottom navigation overlay (sempre visibile)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: NovaBottomNavBar(
                currentIndex: _currentNavIndex,
                items: navItems,
                onTap: _onNavItemSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
