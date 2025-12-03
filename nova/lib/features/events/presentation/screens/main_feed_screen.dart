// =====================================================================
// Nova - Main Feed Screen (BeReal-Inspired Design)
// =====================================================================
// Purpose: Main screen with tab navigation between Eventi and Bacheche
// Architecture: TabController with custom NovaAppBar and NovaBottomNavBar
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../shared/widgets/nova_bottom_nav_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive_dialog.dart';
import '../../../bacheche/presentation/screens/bacheche_screen.dart';
import '../../../auth/providers/user_role_provider.dart';
import 'moderation_queue_screen.dart';
import '../../../admin/presentation/screens/admin_panel_screen.dart';
import '../../../moderation/presentation/providers/pending_count_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'events_feed_screen.dart';
import 'event_creation_screen.dart';

/// Main feed screen with tab navigation (Eventi/Bacheche)
///
/// Features:
/// - NovaAppBar with logo and notifications
/// - Tab bar to switch between Eventi and Bacheche
/// - NovaBottomNavBar with pill-shaped glassmorphic design
/// - Clean white background (BeReal-inspired)
class MainFeedScreen extends ConsumerStatefulWidget {
  const MainFeedScreen({super.key});

  @override
  ConsumerState<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends ConsumerState<MainFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentNavIndex = 0; // Bottom nav index
  String _currentSection = 'Eventi'; // Current section: 'Eventi' or 'Bacheche'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Handle bottom navigation item selection
  void _onNavItemSelected(int index, List<String> navRoutes) {
    setState(() {
      _currentNavIndex = index;
    });

    final route = navRoutes[index];
    switch (route) {
      case 'home':
        _tabController.animateTo(0);
        break;
      case 'friends':
        _showComingSoonDialog('Amici');
        break;
      case 'chat':
        Navigator.push(
          context,
          context.isIOS
              ? CupertinoPageRoute(
                  builder: (context) => const ChatScreen(),
                )
              : MaterialPageRoute(
                  builder: (context) => const ChatScreen(),
                ),
        );
        break;
      case 'moderation':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ModerationQueueScreen(),
          ),
        );
        break;
      case 'admin':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminPanelScreen(),
          ),
        );
        break;
      case 'profile':
        Navigator.push(
          context,
          context.isIOS
              ? CupertinoPageRoute(
                  builder: (context) => const ProfileScreen(),
                )
              : MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
        );
        break;
    }
  }

  /// Build navigation items based on user role
  List<NavItem> _buildNavItems(UserRole userRole, int? pendingCount) {
    final items = <NavItem>[
      const NavItem(
        sfSymbol: 'house.fill',
        materialIcon: Icons.home,
        label: 'Home',
      ),
      const NavItem(
        sfSymbol: 'person.2.fill',
        materialIcon: Icons.people,
        label: 'Amici',
      ),
      const NavItem(
        sfSymbol: 'message.fill',
        materialIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
    ];

    // Add Moderation tab for moderators and admins
    if (userRole == UserRole.moderator || userRole == UserRole.admin) {
      items.add(NavItem(
        sfSymbol: 'gavel',
        materialIcon: Icons.gavel,
        label: 'Moderazione',
        badgeCount: pendingCount,
      ));
    }

    // Add Admin tab for admins only
    if (userRole == UserRole.admin) {
      items.add(const NavItem(
        sfSymbol: 'person.badge.shield.checkmark.fill',
        materialIcon: Icons.admin_panel_settings,
        label: 'Admin',
      ));
    }

    // Always add Profile last
    items.add(const NavItem(
      sfSymbol: 'person.circle.fill',
      materialIcon: Icons.person,
      label: 'Profilo',
    ));

    return items;
  }

  /// Get route identifiers for navigation items based on user role
  List<String> _getNavRoutes(UserRole userRole) {
    final routes = <String>['home', 'friends', 'chat'];

    if (userRole == UserRole.moderator || userRole == UserRole.admin) {
      routes.add('moderation');
    }

    if (userRole == UserRole.admin) {
      routes.add('admin');
    }

    routes.add('profile');

    return routes;
  }

  /// Handle camera FAB tap - Open event creation screen
  void _onCameraTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EventCreationScreen(),
      ),
    );
  }

  /// Show section selector (Eventi/Bacheche)
  void _showSectionSelector() {
    if (context.isIOS) {
      // iOS: Native CupertinoActionSheet
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentSection = 'Eventi';
                  _tabController.animateTo(0);
                });
              },
              isDefaultAction: _currentSection == 'Eventi',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.event, size: 20),
                  SizedBox(width: 8),
                  Text('Eventi'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentSection = 'Bacheche';
                  _tabController.animateTo(1);
                });
              },
              isDefaultAction: _currentSection == 'Bacheche',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.dashboard, size: 20),
                  SizedBox(width: 8),
                  Text('Bacheche'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ),
      );
    } else {
      // Android: Material Design dropdown menu
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          MediaQuery.of(context).size.width / 2 - 100,
          kToolbarHeight,
          MediaQuery.of(context).size.width / 2 + 100,
          0,
        ),
        items: [
          PopupMenuItem(
            value: 'Eventi',
            child: Row(
              children: const [
                Icon(Icons.event, size: 20),
                SizedBox(width: 8),
                Text('Eventi'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'Bacheche',
            child: Row(
              children: const [
                Icon(Icons.dashboard, size: 20),
                SizedBox(width: 8),
                Text('Bacheche'),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value != null) {
          setState(() {
            _currentSection = value;
            _tabController.animateTo(value == 'Eventi' ? 0 : 1);
          });
        }
      });
    }
  }

  /// Show "Coming Soon" dialog for unimplemented features
  void _showComingSoonDialog(String feature) {
    AdaptiveDialog.show(
      context: context,
      title: 'Prossimamente',
      content: 'La funzionalità "$feature" sarà disponibile presto!',
      actions: [
        AdaptiveDialogAction(
          text: 'OK',
          onPressed: () {},
        ),
      ],
    );
  }

  /// Handle notifications icon tap
  void _onNotificationsTap() {
    // TODO(notifications/future): Navigate to NotificationsScreen when implemented
    _showComingSoonDialog('Notifiche');
  }

  @override
  Widget build(BuildContext context) {
    // Watch user role for dynamic navigation
    final userRoleAsync = ref.watch(userRoleProvider);
    final pendingCountAsync = ref.watch(pendingCountProvider);

    // Get current role (default to student if loading/error)
    final userRole = userRoleAsync.valueOrNull ?? UserRole.student;
    final pendingCount = pendingCountAsync.valueOrNull;

    // Build dynamic nav items based on role
    final navItems = _buildNavItems(userRole, pendingCount);
    final navRoutes = _getNavRoutes(userRole);

    // Reset current index if it exceeds available items
    if (_currentNavIndex >= navItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentNavIndex = 0;
        });
      });
    }

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: Stack(
        children: [
          // Main content with SliverAppBar (Instagram-style hide on scroll)
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  floating: false, // Instagram: navbar NON riappare finché non torni in cima
                  pinned: false,   // Navbar scompare completamente scrollando (Instagram behavior)
                  expandedHeight: 56, // Altezza espansa per permettere collapse
                  collapsedHeight: 56, // Stessa altezza per uniformità
                  toolbarHeight: 56, // Aumentato per centrare meglio gli elementi
                  titleSpacing: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    titlePadding: EdgeInsets.zero,
                    title: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Padding per abbassare elementi
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo sinistra
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: SvgPicture.asset(
                              'assets/logos/nova_logo.svg',
                              width: 28,
                              height: 28,
                            ),
                          ),

                          // Titolo centro con dropdown
                          GestureDetector(
                            onTap: _showSectionSelector,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentSection,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),

                          // Notifiche destra
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.black,
                              size: 26,
                            ),
                            onPressed: _onNotificationsTap,
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe, only dropdown changes tabs
              children: const [
                EventsFeedScreen(showAppBar: false),
                BachecheScreen(),
              ],
            ),
          ),

          // Bottom navigation overlay (pill-shaped glassmorphic design)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: NovaBottomNavBar(
                currentIndex: _currentNavIndex,
                items: navItems,
                onTap: (index) => _onNavItemSelected(index, navRoutes),
                onCameraTap: _onCameraTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
