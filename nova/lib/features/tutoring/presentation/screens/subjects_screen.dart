// Screen: SubjectsScreen
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Fiverr-style vertical list of school subjects for tutor search

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/subject.dart';
import '../widgets/subject_list_tile.dart';
import 'tutors_list_screen.dart';

/// SubjectsScreen - Main entry point for tutoring feature
///
/// Displays a Fiverr-style vertical list of school subjects.
/// Each subject shows an icon, title, and description.
/// Tapping a subject navigates to TutorsListScreen for that subject.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar matching MainFeedScreen style
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Ripetizioni',
                  style: NovaTypography.headingMedium.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView.builder(
      itemCount: Subject.values.length,
      itemBuilder: (context, index) {
        final subject = Subject.values[index];
        final isLast = index == Subject.values.length - 1;
        return SubjectListTile(
          subject: subject,
          onTap: () => _navigateToTutorsList(context, subject),
          showDivider: !isLast,
        );
      },
    );
  }

  void _navigateToTutorsList(BuildContext context, Subject subject) {
    Navigator.of(context).push(
      NovaPageRoute.swipeBack(page: TutorsListScreen(subject: subject)),
    );
  }
}
