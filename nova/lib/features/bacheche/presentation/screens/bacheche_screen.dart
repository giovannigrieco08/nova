// Screen: BachecheScreen (Placeholder)
// Purpose: Placeholder for future Bacheche (Request Board) feature

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Placeholder screen for Bacheche feature
///
/// This screen will eventually show:
/// - Collaboration requests from students
/// - Study groups formation
/// - Ride sharing requests
/// - Lost & found items
/// - General announcements
///
/// For now, shows a "Coming Soon" message
class BachecheScreen extends StatelessWidget {
  const BachecheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                Icons.dashboard_outlined,
                size: 80,
                color: NovaColors.textSecondary(context),
              ),

              SizedBox(height: NovaSpacing.xl),

              // Title
              Text(
                'Bacheche',
                style: NovaTextStyles.h1.copyWith(
                  color: NovaColors.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.m),

              // Description
              Text(
                'Presto potrai pubblicare richieste di collaborazione, '
                'trovare compagni di studio e condividere annunci con i tuoi compagni.',
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.xxl),

              // Coming soon badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '🚧 Prossimamente',
                  style: NovaTextStyles.bodyBold.copyWith(
                    color: NovaColors.primary(context),
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
