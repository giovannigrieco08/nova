// Screen: BachecheScreen (Help Requests Aggregated View)
// Purpose: Shows all open help requests from events

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Bacheche screen showing aggregated help requests from events
///
/// Help requests are now integrated directly into events.
/// When creating an event, organizers can add help requests like:
/// - "Cerco fotografo"
/// - "Mi serve un grafico"
/// - "Cerco DJ per la serata"
///
/// This screen shows all open help requests across all events.
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
              // Help icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovaColors.warning(context).withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Icon(
                    Icons.handshake_outlined,
                    size: 50,
                    color: NovaColors.warning(context),
                  ),
                ),
              ),

              SizedBox(height: NovaSpacing.xl),

              // Title
              Text(
                'Richieste di Aiuto',
                style: NovaTypography.headingMedium.copyWith(
                  color: NovaColors.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.m),

              // Description
              Text(
                'Quando crei un evento, puoi aggiungere richieste di aiuto!\n\n'
                '"Cerco fotografo", "Mi serve un grafico"...\n\n'
                'Altri studenti potranno offrirti aiuto direttamente '
                'dalla card dell\'evento.',
                style: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.xxl),

              // Hint to create event
              Container(
                padding: EdgeInsets.all(NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.primary(context).withValues(alpha: 0.1),
                  borderRadius: NovaRadius.circularS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 24,
                      color: NovaColors.primary(context),
                    ),
                    SizedBox(width: NovaSpacing.s),
                    Flexible(
                      child: Text(
                        'Premi + per creare un evento con richieste di aiuto',
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.primary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
