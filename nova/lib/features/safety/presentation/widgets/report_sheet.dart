import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/report.dart';
import '../providers/report_provider.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Bottom sheet for selecting report category and submitting a report
class ReportCategorySheet extends ConsumerStatefulWidget {
  const ReportCategorySheet({
    super.key,
    required this.contentType,
    required this.contentId,
    this.onReportSubmitted,
  });

  final ReportableContentType contentType;
  final String contentId;
  final VoidCallback? onReportSubmitted;

  /// Show the report sheet as a modal bottom sheet
  static Future<bool?> show(
    BuildContext context, {
    required ReportableContentType contentType,
    required String contentId,
    VoidCallback? onReportSubmitted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportCategorySheet(
        contentType: contentType,
        contentId: contentId,
        onReportSubmitted: onReportSubmitted,
      ),
    );
  }

  @override
  ConsumerState<ReportCategorySheet> createState() =>
      _ReportCategorySheetState();
}

class _ReportCategorySheetState extends ConsumerState<ReportCategorySheet> {
  ReportCategory? _selectedCategory;
  final _noteController = TextEditingController();
  bool _showNoteField = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportNotifierProvider);
    final theme = Theme.of(context);

    ref.listen<ReportState>(reportNotifierProvider, (previous, next) {
      if (next.isSubmitted) {
        // Show toast before closing
        NovaToast.showSuccess(
            context, 'Segnalazione inviata. Grazie per il tuo contributo.');
        Navigator.of(context).pop(true);
        widget.onReportSubmitted?.call();
      } else if (next.error != null) {
        NovaToast.showError(context, next.error!);
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Segnala contenuto',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Seleziona il motivo della segnalazione',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha:0.7),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Category options
              ...ReportCategory.values.map((category) => _buildCategoryTile(
                    context,
                    category: category,
                    isSelected: _selectedCategory == category,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _showNoteField = category == ReportCategory.other;
                      });
                    },
                  )),

              // Note field (shown for "Other" category)
              if (_showNoteField) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _noteController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Descrivi il problema...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _selectedCategory == null || reportState.isLoading
                            ? null
                            : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: reportState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Invia segnalazione',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required ReportCategory category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    _getCategoryDescription(category),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha:0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDescription(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return 'Contenuto commerciale o ripetitivo';
      case ReportCategory.offensiveContent:
        return 'Linguaggio volgare o offensivo';
      case ReportCategory.bullying:
        return 'Comportamento intimidatorio o molesto';
      case ReportCategory.inappropriate:
        return 'Non adatto all\'ambiente scolastico';
      case ReportCategory.other:
        return 'Motivo diverso (specifica nella nota)';
    }
  }

  void _submitReport() {
    if (_selectedCategory == null) return;

    ref.read(reportNotifierProvider.notifier).submitReport(
          contentType: widget.contentType,
          contentId: widget.contentId,
          category: _selectedCategory!,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
  }
}
