// =====================================================================
// Nova - Splash Screen
// =====================================================================
// Purpose: Branded splash screen with logo → circle → expansion animation
// Architecture: StatefulWidget with implicit animations
// Inspiration: red_dot_splash_animation (adapted for Nova design system)
// Animation: Logo appears → morphs to white circle → circle expands to fill screen
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/widgets/nova_logo.dart';
import 'package:nova/main.dart'; // For AuthGuard

// Custom elastic curve from red_dot_splash_animation
// Creates smooth "spring" effect during expansion
const Curve _elasticCurve = Cubic(0.58, -0.30, 0.365, 1);

/// Nova splash screen with logo → circle expansion animation
///
/// Animation sequence:
/// 1. Logo fades in (400ms)
/// 2. Logo → Circle crossfade (300ms)
/// 3. Circle expands 10x with elastic curve (600ms)
/// 4. Navigate to AuthGuard with fade transition
///
/// Total duration: ~1.7 seconds
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Animation state flags
  bool _showLogo = false;      // Phase 1: Logo fade-in
  bool _showCircle = false;    // Phase 2: Logo→Circle morph
  bool _expandCircle = false;  // Phase 3: Circle expansion

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  /// Start splash animation sequence
  Future<void> _startAnimation() async {
    // Wait for initial frame to render
    await Future.delayed(const Duration(milliseconds: 100));

    // Phase 1: Show logo (fade-in)
    if (mounted) {
      setState(() {
        _showLogo = true;
      });
    }

    // Phase 2: Logo → Circle morph (after logo is visible)
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _showCircle = true;
      });
    }

    // Phase 3: Expand circle (after morph crossfade completes)
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _expandCircle = true;
      });
    }

    // Phase 4: Navigate to AuthGuard (after expansion completes + buffer)
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      _navigateToApp();
    }
  }

  /// Navigate to AuthGuard with fade transition
  void _navigateToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGuard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.backgroundDark, // Pure black background
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Nova Logo (visible until circle appears, then fades out)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: !_showCircle ? 1.0 : 0.0,
              curve: Curves.easeOut,
              child: const NovaLogo.extraLarge(
                color: NovaColors.textPrimaryDark, // White logo
              ),
            ),

            // Layer 2: White Circle (fades in, then expands)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showCircle ? 1.0 : 0.0,
              curve: Curves.easeIn,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 600),
                scale: _expandCircle ? 10.0 : 1.0,
                curve: _elasticCurve, // Red dot elastic curve for smooth expansion
                child: Container(
                  width: 120, // Match NovaLogo.extraLarge size
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NovaColors.textPrimaryDark, // White circle
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
