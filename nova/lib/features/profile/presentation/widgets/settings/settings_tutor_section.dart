import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/animations/page_transitions.dart';
import '../../../../../core/theme/nova_spacing.dart';
import '../../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../../tutoring/presentation/screens/become_tutor_screen.dart';
import '../../../../tutoring/presentation/screens/edit_tutor_screen.dart';
import 'settings_tile_builders.dart';

/// Section 4: Ripetizioni (Tutor T049-T052).
class SettingsTutorSection extends ConsumerWidget {
  const SettingsTutorSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorAsync = ref.watch(currentTutorProfileProvider);

    return SettingsSectionCard(
      child: tutorAsync.when(
        data: (tutorProfile) {
          if (tutorProfile == null) {
            return SettingsActionTile(
              icon: Icons.school_rounded,
              title: 'Diventa Tutor',
              subtitle: 'Offri ripetizioni ai tuoi compagni',
              onTap: () => Navigator.push(
                context,
                NovaPageRoute.swipeBack(page: const BecomeTutorScreen()),
              ),
            );
          } else {
            return Column(
              children: [
                SettingsActionTile(
                  icon: Icons.edit_rounded,
                  title: 'Gestisci Profilo Tutor',
                  subtitle: tutorProfile.isActive
                      ? '${tutorProfile.subjects.length} materie • ${tutorProfile.priceDisplay}'
                      : 'Profilo disattivato',
                  onTap: () => Navigator.push(
                    context,
                    NovaPageRoute.swipeBack(
                        page: EditTutorScreen(profile: tutorProfile)),
                  ),
                ),
                if (!tutorProfile.isActive) ...[
                  const SettingsDivider(),
                  SettingsActionTile(
                    icon: Icons.visibility_rounded,
                    title: 'Riattiva Profilo',
                    subtitle: 'Torna visibile agli altri studenti',
                    onTap: () async {
                      final notifier =
                          ref.read(toggleTutorActiveProvider.notifier);
                      final result = await notifier.reactivate();
                      if (result != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profilo tutor riattivato!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            );
          }
        },
        loading: () => Padding(
          padding: EdgeInsets.all(NovaSpacing.medium),
          child: const Center(child: AdaptiveLoadingIndicator()),
        ),
        error: (_, __) => SettingsActionTile(
          icon: Icons.school_rounded,
          title: 'Diventa Tutor',
          subtitle: 'Offri ripetizioni ai tuoi compagni',
          onTap: () => Navigator.push(
            context,
            NovaPageRoute.swipeBack(page: const BecomeTutorScreen()),
          ),
        ),
      ),
    );
  }
}
