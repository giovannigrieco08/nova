// Screen: SubjectsScreen
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Fiverr-style vertical list of school subjects for tutor search

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
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
    return Platform.isIOS
        ? _buildCupertinoScreen(context, ref)
        : _buildMaterialScreen(context, ref);
  }

  Widget _buildCupertinoScreen(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Ripetizioni',
          style: NovaTypography.headingMedium,
        ),
        backgroundColor: NovaColors.surface(context),
        border: null,
      ),
      backgroundColor: NovaColors.background(context),
      child: SafeArea(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: NovaColors.textPrimary(context),
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ripetizioni',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: NovaColors.background(context),
      body: SafeArea(
        child: _buildContent(context),
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
