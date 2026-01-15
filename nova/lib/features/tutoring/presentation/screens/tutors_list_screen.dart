// Screen: TutorsListScreen
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: List of tutors for a specific subject with contact sheet

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/subject.dart';
import '../../data/repositories/tutor_repository.dart';
import '../providers/tutor_providers.dart';
import '../widgets/tutor_card.dart';
import '../widgets/tutor_skeleton.dart';
import '../widgets/contact_tutor_sheet.dart';

/// TutorsListScreen - List of tutors for a specific subject
///
/// Shows paginated list of active tutors who offer the selected subject.
/// Tapping a tutor shows ContactTutorSheet bottom sheet.
class TutorsListScreen extends ConsumerStatefulWidget {
  /// The subject to filter tutors by
  final Subject subject;

  const TutorsListScreen({
    super.key,
    required this.subject,
  });

  @override
  ConsumerState<TutorsListScreen> createState() => _TutorsListScreenState();
}

class _TutorsListScreenState extends ConsumerState<TutorsListScreen> {
  String? _priceFilter;
  String? _classFilter;

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? _buildCupertinoScreen(context)
        : _buildMaterialScreen(context);
  }

  Widget _buildCupertinoScreen(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.subject.displayName),
        backgroundColor: NovaColors.surface(context),
        border: null,
      ),
      backgroundColor: NovaColors.background(context),
      child: SafeArea(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context) {
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
        title: Text(widget.subject.displayName),
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
    // Watch tutors for this subject with optional filters
    final hasFilters = _priceFilter != null || _classFilter != null;
    final tutorsAsync = !hasFilters
        ? ref.watch(tutorsBySubjectProvider(widget.subject))
        : ref.watch(filteredTutorsProvider(
            TutorFilterParams(
              subject: widget.subject,
              priceFilter: _priceFilter,
              classFilter: _classFilter,
            ),
          ));

    return Column(
      children: [
        // Filter chips rows (price + class)
        _buildFilterSection(context),
        // Tutors list
        Expanded(
          child: tutorsAsync.when(
            data: (tutors) => tutors.isEmpty
                ? _buildEmptyState(context)
                : _buildTutorsList(context, tutors),
            loading: () => _buildLoadingState(context),
            error: (error, _) => _buildErrorState(context, error),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Price filter row
        _buildPriceFilterChips(context),
        // Class filter row
        _buildClassFilterChips(context),
      ],
    );
  }

  Widget _buildPriceFilterChips(BuildContext context) {
    final filters = [
      ('Tutti', null),
      ('Gratis', 'free'),
      ('€1-15', '1-15'),
      ('€16-30', '16-30'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.only(top: NovaSpacing.s),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: NovaSpacing.s),
        itemBuilder: (context, index) {
          final (label, value) = filters[index];
          final isSelected = _priceFilter == value;

          return Platform.isIOS
              ? _buildCupertinoChip(context, label, isSelected, () {
                  setState(() => _priceFilter = value);
                })
              : _buildMaterialChip(context, label, isSelected, () {
                  setState(() => _priceFilter = value);
                });
        },
      ),
    );
  }

  Widget _buildClassFilterChips(BuildContext context) {
    final classFilters = [
      ('Tutte', null),
      ('1°', '1'),
      ('2°', '2'),
      ('3°', '3'),
      ('4°', '4'),
      ('5°', '5'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.only(bottom: NovaSpacing.s),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l),
        itemCount: classFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: NovaSpacing.s),
        itemBuilder: (context, index) {
          final (label, value) = classFilters[index];
          final isSelected = _classFilter == value;

          return Platform.isIOS
              ? _buildCupertinoChip(context, label, isSelected, () {
                  setState(() => _classFilter = value);
                })
              : _buildMaterialChip(context, label, isSelected, () {
                  setState(() => _classFilter = value);
                });
        },
      ),
    );
  }

  Widget _buildCupertinoChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? NovaColors.primary(context)
              : NovaColors.card(context),
          borderRadius: NovaRadius.circularL,
          border: isSelected
              ? null
              : Border.all(color: NovaColors.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : NovaColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: NovaColors.primary(context),
      backgroundColor: NovaColors.card(context),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : NovaColors.textPrimary(context),
      ),
      checkmarkColor: Colors.white,
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: NovaColors.border(context)),
    );
  }

  Widget _buildTutorsList(
    BuildContext context,
    List<TutorProfileWithAuthorData> tutors,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate provider to refresh
        final hasFilters = _priceFilter != null || _classFilter != null;
        if (!hasFilters) {
          ref.invalidate(tutorsBySubjectProvider(widget.subject));
        } else {
          ref.invalidate(filteredTutorsProvider(
            TutorFilterParams(
              subject: widget.subject,
              priceFilter: _priceFilter,
              classFilter: _classFilter,
            ),
          ));
        }
      },
      color: NovaColors.primary(context),
      child: ListView.builder(
        padding: const EdgeInsets.all(NovaSpacing.l),
        itemCount: tutors.length,
        itemBuilder: (context, index) {
          final tutor = tutors[index];
          return TutorCard(
            tutor: tutor,
            onTap: () => _showContactSheet(context, tutor),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const TutorsListSkeleton();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS
                  ? CupertinoIcons.book
                  : Icons.school_outlined,
              size: 64,
              color: NovaColors.textTertiary(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Nessun tutor disponibile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Non ci sono ancora tutor per ${widget.subject.displayName}.\nDiventa il primo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS
                  ? CupertinoIcons.exclamationmark_triangle
                  : Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Errore nel caricamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: NovaColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.l),
            if (Platform.isIOS)
              CupertinoButton(
                onPressed: () {
                  ref.invalidate(tutorsBySubjectProvider(widget.subject));
                },
                child: const Text('Riprova'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(tutorsBySubjectProvider(widget.subject));
                },
                child: const Text('Riprova'),
              ),
          ],
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context, TutorProfileWithAuthorData tutor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactTutorSheet(tutor: tutor),
    );
  }
}
