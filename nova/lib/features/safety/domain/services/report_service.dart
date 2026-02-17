import '../../data/models/report.dart';
import '../../data/repositories/report_repository.dart';

/// Service for managing content reports
///
/// Provides business logic layer between UI and repository
class ReportService {
  ReportService({ReportRepository? repository})
      : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;

  /// Submit a report for content
  ///
  /// Validates inputs and delegates to repository
  /// Returns the created report
  Future<Report> submitReport({
    required ReportableContentType contentType,
    required String contentId,
    required ReportCategory category,
    String? note,
  }) async {
    // Validate content ID
    if (contentId.isEmpty) {
      throw ArgumentError('ID contenuto non valido');
    }

    // Check if already reported
    final alreadyReported = await _repository.hasUserReported(
      contentType: contentType,
      contentId: contentId,
    );

    if (alreadyReported) {
      throw ReportAlreadyExistsException();
    }

    // Create the report
    return _repository.createReport(
      contentType: contentType,
      contentId: contentId,
      category: category,
      note: note?.trim(),
    );
  }

  /// Check if user can report this content
  ///
  /// Returns true if not already reported
  Future<bool> canReport({
    required ReportableContentType contentType,
    required String contentId,
  }) async {
    final alreadyReported = await _repository.hasUserReported(
      contentType: contentType,
      contentId: contentId,
    );
    return !alreadyReported;
  }

  /// Get user's report history
  Future<List<Report>> getMyReports({
    int limit = 50,
    int offset = 0,
  }) async {
    return _repository.getUserReports(
      limit: limit,
      offset: offset,
    );
  }

  /// Get the status of a user's report on specific content
  Future<ReportStatus?> getReportStatus({
    required ReportableContentType contentType,
    required String contentId,
  }) async {
    return _repository.getReportStatus(
      contentType: contentType,
      contentId: contentId,
    );
  }
}

/// Exception thrown when user has already reported this content
class ReportAlreadyExistsException implements Exception {
  @override
  String toString() => 'Hai già segnalato questo contenuto';
}
