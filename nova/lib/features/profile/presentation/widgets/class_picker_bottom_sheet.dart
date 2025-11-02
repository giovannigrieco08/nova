// Widget: ClassPickerBottomSheet
// Feature: 002-profile-setup
// Purpose: Searchable class picker with sections

import 'package:flutter/material.dart';
import '../../../../core/constants/classes.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/nova_bottom_sheet.dart';

/// Searchable class picker bottom sheet
///
/// Features:
/// - Search bar for filtering classes
/// - Sections: SCIENTIFICO (25 classes), CLASSICO (10 classes)
/// - Single selection with check icon
/// - 60fps smooth scrolling
class ClassPickerBottomSheet extends StatefulWidget {
  final String? selectedClass;
  final Function(String) onClassSelected;

  const ClassPickerBottomSheet({
    super.key,
    this.selectedClass,
    required this.onClassSelected,
  });

  /// Show class picker bottom sheet
  static Future<String?> show(
    BuildContext context, {
    String? selectedClass,
  }) {
    return NovaBottomSheet.show<String>(
      context: context,
      initialChildSize: 0.7,
      builder: (context, scrollController) {
        return ClassPickerBottomSheet(
          selectedClass: selectedClass,
          onClassSelected: (className) {
            Navigator.of(context).pop(className);
          },
        );
      },
    );
  }

  @override
  State<ClassPickerBottomSheet> createState() =>
      _ClassPickerBottomSheetState();
}

class _ClassPickerBottomSheetState extends State<ClassPickerBottomSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter classes by search query
  List<SchoolClass> _filterClasses(List<SchoolClass> classes) {
    if (_searchQuery.isEmpty) {
      return classes;
    }

    return classes
        .where((c) =>
            c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scientificoClasses = _filterClasses(
      allClasses.where((c) => c.track == 'SCIENTIFICO').toList(),
    );
    final classicoClasses = _filterClasses(
      allClasses.where((c) => c.track == 'CLASSICO').toList(),
    );

    return Column(
      children: [
        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.xl,
            vertical: NovaSpacing.l,
          ),
          child: Text(
            'Seleziona classe',
            style: NovaTextStyles.h2.copyWith(
              color: NovaColors.textPrimary(context),
            ),
          ),
        ),

        // Search bar
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.xl,
            vertical: NovaSpacing.m,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cerca classe...',
              hintStyle: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: NovaColors.textSecondary(context),
              ),
              filled: true,
              fillColor: NovaColors.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: NovaSpacing.l,
                vertical: NovaSpacing.m,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Class list
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: NovaSpacing.xl),
            children: [
              // SCIENTIFICO section
              if (scientificoClasses.isNotEmpty) ...[
                _buildSectionHeader(context, 'SCIENTIFICO'),
                ...scientificoClasses.map(
                  (schoolClass) => _buildClassTile(context, schoolClass),
                ),
              ],

              // CLASSICO section
              if (classicoClasses.isNotEmpty) ...[
                SizedBox(height: NovaSpacing.l),
                _buildSectionHeader(context, 'CLASSICO'),
                ...classicoClasses.map(
                  (schoolClass) => _buildClassTile(context, schoolClass),
                ),
              ],

              // No results
              if (scientificoClasses.isEmpty && classicoClasses.isEmpty)
                _buildNoResults(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.xl,
        vertical: NovaSpacing.m,
      ),
      child: Text(
        title,
        style: NovaTextStyles.caption.copyWith(
          color: NovaColors.textSecondary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Build class tile
  Widget _buildClassTile(BuildContext context, SchoolClass schoolClass) {
    final isSelected = widget.selectedClass == schoolClass.id;

    return ListTile(
      title: Text(
        schoolClass.displayName,
        style: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: NovaColors.primary(context),
            )
          : null,
      onTap: () {
        widget.onClassSelected(schoolClass.id);
      },
    );
  }

  /// Build no results message
  Widget _buildNoResults(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Nessuna classe trovata',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
