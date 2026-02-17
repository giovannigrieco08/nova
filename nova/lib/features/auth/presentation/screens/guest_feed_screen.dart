// =====================================================================
// Nova - Guest Feed Screen (Apple Guideline 5.1.1 Compliance)
// =====================================================================
// Purpose: Instagram-style feed for unauthenticated users
// Users can browse events freely, login required only for interactions
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../events/presentation/screens/events_feed_screen.dart';
import '../providers/auth_notifier.dart';

/// Guest feed screen - Instagram-style browsing without login
///
/// Apple Guideline 5.1.1 requires that users can access non-account-based
/// features without logging in. Events viewing doesn't require an account.
///
/// Features:
/// - Full events feed browsing
/// - Sign-in banner at bottom (non-intrusive)
/// - Tapping interactions prompts login
class GuestFeedScreen extends ConsumerWidget {
  const GuestFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // Events feed (read-only mode)
          const EventsFeedScreen(
            showAppBar: true,
            disableRefresh: false,
          ),
          // Sign-in banner at bottom (Instagram-style)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SignInBanner(
              onSignIn: () =>
                  ref.read(authNotifierProvider.notifier).showLogin(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact sign-in banner for guest mode
class _SignInBanner extends StatelessWidget {
  final VoidCallback onSignIn;

  const _SignInBanner({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.s,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Accedi per interagire con gli eventi',
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(width: NovaSpacing.s),
              ElevatedButton(
                onPressed: onSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: NovaSpacing.l,
                    vertical: NovaSpacing.s,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NovaRadius.m),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Accedi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show sign-in prompt when guest tries to interact
///
/// Call this from any interaction handler (like, comment, participate)
/// when the user is not authenticated.
void showGuestSignInPrompt({
  required BuildContext context,
  required WidgetRef ref,
  required String action,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.l)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.handleBar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: NovaSpacing.xl),
          // Icon
          Icon(
            Icons.login_rounded,
            size: 48,
            color: NovaColors.primary(sheetContext),
          ),
          const SizedBox(height: NovaSpacing.m),
          // Title
          Text(
            action,
            style: NovaTypography.headingSmall.copyWith(
              color: NovaColors.textPrimary(sheetContext),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NovaSpacing.s),
          // Subtitle
          Text(
            'Usa la tua email scolastica per accedere e partecipare alla community.',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondary(sheetContext),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NovaSpacing.xl),
          // Sign in button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                ref.read(authNotifierProvider.notifier).showLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(sheetContext),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                ),
                elevation: 0,
              ),
              child: Text(
                'Accedi',
                style: NovaTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.s),
          // Continue browsing
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(
              'Continua a sfogliare',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(sheetContext),
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.m),
        ],
      ),
    ),
  );
}
