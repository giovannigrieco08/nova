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
import 'events_feed_screen.dart';

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
        break;
      case 2: // Chat
        _showComingSoonDialog('Chat');
        break;
      case 3: // Profilo
        _showComingSoonDialog('Profilo');
        break;
    }
  }

  /// Handle camera FAB tap
  void _onCameraTap() {
    _showComingSoonDialog('Camera');
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

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AdaptiveAppBar(
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
          // Main content
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
