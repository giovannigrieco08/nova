// Screen: SubjectsScreen
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Grid of 12 school subjects for tutor search

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/subject.dart';
import '../providers/tutor_providers.dart';
import '../widgets/subject_card.dart';
import 'tutors_list_screen.dart';

/// SubjectsScreen - Main entry point for tutoring feature
///
/// Displays a 3-column grid of 12 school subjects.
/// Tapping a subject navigates to TutorsListScreen for that subject.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Platform.isIOS
        ? _buildCupertinoScreen(context, ref)
        : _buildMaterialScreen(context, ref);
  }

  Widget _buildCupertinoScreen(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Ripetizioni'),
        backgroundColor: NovaColors.surface(context),
        border: null,
        trailing: _buildFabButton(context, ref),
      ),
      backgroundColor: NovaColors.background(context),
      child: SafeArea(
        child: _buildContent(context, ref),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ripetizioni'),
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: _buildContent(context, ref),
      ),
      floatingActionButton: _buildFab(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        // Header text
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(NovaSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trova un tutor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: NovaSpacing.xs),
                Text(
                  'Scegli una materia per vedere i tutor disponibili',
                  style: TextStyle(
                    fontSize: 14,
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Subject grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: NovaSpacing.m,
              crossAxisSpacing: NovaSpacing.m,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final subject = Subject.values[index];
                return SubjectCard(
                  subject: subject,
                  onTap: () => _navigateToTutorsList(context, subject),
                );
              },
              childCount: Subject.values.length,
            ),
          ),
        ),
        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: NovaSpacing.xxxl),
        ),
      ],
    );
  }

  /// FAB for "Diventa Tutor" (iOS button style)
  Widget? _buildFabButton(BuildContext context, WidgetRef ref) {
    final isTutorAsync = ref.watch(isTutorProvider);

    return isTutorAsync.when(
      data: (isTutor) => CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _navigateToBecomeTutor(context, isTutor),
        child: Icon(
          isTutor ? CupertinoIcons.pencil : CupertinoIcons.add,
          color: NovaColors.primary(context),
        ),
      ),
      loading: () => null,
      error: (_, __) => null,
    );
  }

  /// FAB for "Diventa Tutor" (Material style)
  Widget? _buildFab(BuildContext context, WidgetRef ref) {
    final isTutorAsync = ref.watch(isTutorProvider);

    return isTutorAsync.when(
      data: (isTutor) => FloatingActionButton.extended(
        onPressed: () => _navigateToBecomeTutor(context, isTutor),
        backgroundColor: NovaColors.primary(context),
        foregroundColor: Colors.white,
        icon: Icon(isTutor ? Icons.edit : Icons.add),
        label: Text(isTutor ? 'Modifica' : 'Diventa Tutor'),
      ),
      loading: () => null,
      error: (_, __) => null,
    );
  }

  void _navigateToTutorsList(BuildContext context, Subject subject) {
    Navigator.of(context).push(
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (_) => TutorsListScreen(subject: subject),
            )
          : MaterialPageRoute(
              builder: (_) => TutorsListScreen(subject: subject),
            ),
    );
  }

  void _navigateToBecomeTutor(BuildContext context, bool isTutor) {
    // TODO: Navigate to BecomeTutorScreen or EditTutorScreen
    // Will be implemented in Phase 4 (T022-T028)
  }
}
