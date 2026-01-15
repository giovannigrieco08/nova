// =====================================================================
// Nova - Splash Screen (Minimal Instagram/BeReal Style)
// =====================================================================
// Purpose: Ultra-minimal splash with simple fade-in animation
// Architecture: StatefulWidget with AnimationController
// Duration: ~1 second total (400ms fade-in + 300ms transition)
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/widgets/nova_logo.dart';
import 'package:nova/main.dart'; // For AuthGuard

/// Nova splash screen - minimal Instagram/BeReal style
///
/// Animation sequence:
/// 1. Logo fades in (400ms, easeOut)
/// 2. Hold (600ms)
/// 3. Navigate to AuthGuard with fade transition (300ms)
///
/// Total duration: ~1 second
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start fade-in animation
    _controller.forward();

    // Navigate after 1000ms total (visible splash screen)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _navigateToAuth();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Navigate to AuthGuard with fade transition
  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGuard(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black - Instagram/BeReal style
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const NovaLogo.extraLarge(
            color: Colors.white, // White logo on black
          ),
        ),
      ),
    );
  }
}
