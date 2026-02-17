import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/report.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/services/report_service.dart';

/// Provider for ReportRepository
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

/// Provider for ReportService
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(
    repository: ref.watch(reportRepositoryProvider),
  );
});

/// State for report submission
class ReportState {
  const ReportState({
    this.isLoading = false,
    this.isSubmitted = false,
    this.error,
  });

  final bool isLoading;
  final bool isSubmitted;
  final String? error;

  ReportState copyWith({
    bool? isLoading,
    bool? isSubmitted,
    String? error,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      error: error,
    );
  }
}

/// Notifier for managing report submission state
class ReportNotifier extends StateNotifier<ReportState> {
  ReportNotifier(this._service) : super(const ReportState());

  final ReportService _service;

  /// Submit a report
  Future<bool> submitReport({
    required ReportableContentType contentType,
    required String contentId,
    required ReportCategory category,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.submitReport(
        contentType: contentType,
        contentId: contentId,
        category: category,
        note: note,
      );

      state = state.copyWith(isLoading: false, isSubmitted: true);
      return true;
    } on ReportAlreadyExistsException {
      state = state.copyWith(
        isLoading: false,
        error: 'Hai già segnalato questo contenuto',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la segnalazione: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset state for new report
  void reset() {
    state = const ReportState();
  }
}

/// Provider for report submission state
final reportNotifierProvider =
    StateNotifierProvider.autoDispose<ReportNotifier, ReportState>((ref) {
  return ReportNotifier(ref.watch(reportServiceProvider));
});

/// Provider to check if content has been reported by current user
final hasReportedProvider = FutureProvider.family<bool,
    ({ReportableContentType contentType, String contentId})>(
  (ref, params) async {
    final service = ref.watch(reportServiceProvider);
    final canReport = await service.canReport(
      contentType: params.contentType,
      contentId: params.contentId,
    );
    return !canReport;
  },
);

/// Provider for user's report history
final userReportsProvider = FutureProvider<List<Report>>((ref) async {
  final service = ref.watch(reportServiceProvider);
  return service.getMyReports();
});
