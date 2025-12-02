// =====================================================================
// Nova - Main Feed Screen (BeReal-Inspired Design)
// =====================================================================
// Purpose: Main screen with tab navigation between Eventi and Bacheche
// Architecture: TabController with custom NovaAppBar and NovaBottomNavBar
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_icons.dart';
import '../../../../shared/widgets/nova_tabs.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_app_bar.dart';
import '../../../../shared/widgets/nova_bottom_nav_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive_dialog.dart';
import '../../../bacheche/presentation/screens/bacheche_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
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
    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        _tabController.animateTo(0);
        break;
      case 1: // Amici
        _showComingSoonDialog('Amici');
        // Reset to Home after showing dialog
        setState(() => _currentNavIndex = 0);
        break;
      case 2: // Chat
        // ChatScreen is now shown via IndexedStack
        break;
      case 3: // Profilo
        // ProfileScreen is now shown via IndexedStack
        break;
    }
  }

  /// Handle camera FAB tap - navigate to create event
  void _onCameraTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EventCreationScreen(),
      ),
    );
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
    // TODO: Open notifications screen
    _showComingSoonDialog('Notifiche');
  }

  /// Get IndexedStack index from nav index
  int _getStackIndex() {
    switch (_currentNavIndex) {
      case 0: return 0; // Home
      case 2: return 1; // Chat
      case 3: return 2; // Profilo
      default: return 0;
    }
  }

  /// Check if current screen has its own app bar
  bool _screenHasOwnAppBar() {
    return _currentNavIndex == 2 || _currentNavIndex == 3; // Chat and Profile
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _screenHasOwnAppBar()
          ? null // Chat and Profile screens have their own AppBar
          : AdaptiveAppBar(
              title: const Text('Nova'),
              actions: [
                IconButton(
                  icon: NovaIcons.notifications(context),
                  onPressed: _onNotificationsTap,
                ),
              ],
            ),
      body: Stack(
        children: [
          // Main content using IndexedStack to preserve state
          IndexedStack(
            index: _getStackIndex(),
            children: [
              // Index 0: Home feed (Eventi/Bacheche tabs)
              Column(
                children: [
                  // Tab bar (Eventi / Bacheche)
                  NovaTabs(
                    controller: _tabController,
                    tab1Label: 'Eventi',
                    tab2Label: 'Bacheche',
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        // Eventi tab
                        EventsFeedScreen(showAppBar: false),

                        // Bacheche tab
                        BachecheScreen(),
                      ],
                    ),
                  ),

                  // Bottom padding for nav bar
                  const SizedBox(height: 100),
                ],
              ),

              // Index 1: Chat screen
              const Column(
                children: [
                  Expanded(child: ChatScreen()),
                  // Bottom padding for nav bar
                  SizedBox(height: 100),
                ],
              ),

              // Index 2: Profile screen
              const Column(
                children: [
                  Expanded(child: ProfileScreen()),
                  // Bottom padding for nav bar
                  SizedBox(height: 100),
                ],
              ),
            ],
          ),

          // Bottom navigation overlay (pill-shaped glassmorphic design)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: NovaBottomNavBar(
                currentIndex: _currentNavIndex,
                onTap: _onNavItemSelected,
                onCameraTap: _onCameraTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
