// =====================================================================
// Nova - Main Feed Screen (BeReal-Inspired Design)
// =====================================================================
// Purpose: Main screen with tab navigation between Eventi and Bacheche
// Architecture: TabController with custom NovaAppBar and NovaBottomNavBar
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../shared/widgets/nova_bottom_nav_bar.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../bacheche/presentation/screens/bacheche_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../tutoring/presentation/screens/subjects_screen.dart';
import '../../../notifications/presentation/screens/notification_list_screen.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
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
  int _currentNavIndex = 0; // Bottom nav index (0=Home, 1=Search, 2=Tutoring, 3=Chat, 4=Profile)
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
      context.isIOS
          ? CupertinoPageRoute(builder: (context) => const ChatScreen())
          : MaterialPageRoute(builder: (context) => const ChatScreen()),
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

  /// Handle create button tap - Open event/bacheca creation screen
  void _onCreateTap() {
    Navigator.push(
      context,
      context.isIOS
          ? CupertinoPageRoute(
              builder: (context) => const EventCreationScreen(),
            )
          : MaterialPageRoute(
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

  /// Handle notifications icon tap
  void _onNotificationsTap() {
    Navigator.push(
      context,
      context.isIOS
          ? CupertinoPageRoute(builder: (context) => const NotificationListScreen())
          : MaterialPageRoute(builder: (context) => const NotificationListScreen()),
    );
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

  /// Build the Home screen with Eventi/Bacheche tabs
  Widget _buildHomeScreen() {
    return NestedScrollView(
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
                  // Sinistra: Pulsante + (stile Instagram)
                  GestureDetector(
                    onTap: _onCreateTap,
                    child: Icon(
                      context.isIOS ? CupertinoIcons.plus : Icons.add,
                      color: NovaColors.textPrimary(context),
                      size: 24,
                    ),
                  ),

                  // Centro: Titolo sezione con dropdown (stile Instagram "Per te")
                  GestureDetector(
                    onTap: _showSectionSelector,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentSection,
                          style: NovaTypography.headingMedium.copyWith(
                            color: NovaColors.textPrimary(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: NovaColors.textPrimary(context),
                        ),
                      ],
                    ),
                  ),

                  // Destra: Campanella notifiche con badge (stile Instagram)
                  GestureDetector(
                    onTap: _onNotificationsTap,
                    child: _buildNotificationBell(context),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          EventsFeedScreen(showAppBar: false),
          BachecheScreen(),
        ],
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
