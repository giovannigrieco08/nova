import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report.dart';

/// Repository for managing content reports
class ReportRepository {
  ReportRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Create a new report for content
  ///
  /// Returns the created report on success
  /// Throws if report already exists or validation fails
  Future<Report> createReport({
    required ReportableContentType contentType,
    required String contentId,
    required ReportCategory category,
    String? note,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    // Validate note length
    if (note != null && note.length > 500) {
      throw Exception('La nota non può superare 500 caratteri');
    }

    final response = await _supabase
        .from('reports')
        .insert({
          'reporter_id': userId,
          'content_type': contentType.value,
          'content_id': contentId,
          'category': category.value,
          if (note != null && note.isNotEmpty) 'note': note,
        })
        .select()
        .single();

    return Report.fromJson(response);
  }

  /// Check if current user has already reported this content
  Future<bool> hasUserReported({
    required ReportableContentType contentType,
    required String contentId,
  }) async {
    final result = await _supabase.rpc(
      'has_user_reported',
      params: {
        'p_content_type': contentType.value,
        'p_content_id': contentId,
      },
    );

    return result as bool? ?? false;
  }

  /// Get all reports created by current user
  Future<List<Report>> getUserReports({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    final response = await _supabase
        .from('reports')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((json) => Report.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single report by ID
  Future<Report?> getReportById(String reportId) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('id', reportId)
        .maybeSingle();

    if (response == null) return null;
    return Report.fromJson(response);
  }

  /// Get report status for a specific content (for UI indicators)
  Future<ReportStatus?> getReportStatus({
    required ReportableContentType contentType,
    required String contentId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('reports')
        .select('status')
        .eq('reporter_id', userId)
        .eq('content_type', contentType.value)
        .eq('content_id', contentId)
        .maybeSingle();

    if (response == null) return null;
    return ReportStatus.fromString(response['status'] as String);
  }
}
