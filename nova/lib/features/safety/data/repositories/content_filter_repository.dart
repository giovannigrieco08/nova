import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_check_result.dart';

/// Repository for content filtering operations
class ContentFilterRepository {
  ContentFilterRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Check content against banned words
  ///
  /// Returns result indicating if content is allowed/blocked
  Future<ContentCheckResult> checkContent(String text) async {
    if (text.isEmpty) {
      return ContentCheckResult.clean();
    }

    final result = await _supabase.rpc(
      'check_content',
      params: {'p_text': text},
    );

    if (result == null) {
      return ContentCheckResult.clean();
    }

    return ContentCheckResult.fromJson(result as Map<String, dynamic>);
  }

  /// Get list of banned words (for moderators)
  Future<List<BannedWord>> getBannedWords({
    String? language,
    bool includeDeleted = false,
  }) async {
    var query = _supabase.from('banned_words').select();

    if (!includeDeleted) {
      query = query.isFilter('deleted_at', null);
    }

    if (language != null) {
      query = query.eq('language', language);
    }

    final response = await query.order('word');

    return (response as List<dynamic>)
        .map((json) => BannedWord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Add a new banned word (moderators only)
  Future<BannedWord> addBannedWord({
    required String word,
    required String patternType,
    required String severity,
    String language = 'it',
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    final response = await _supabase
        .from('banned_words')
        .insert({
          'word': word,
          'pattern_type': patternType,
          'severity': severity,
          'language': language,
          'created_by': userId,
        })
        .select()
        .single();

    return BannedWord.fromJson(response);
  }

  /// Remove a banned word (soft delete, moderators only)
  Future<void> removeBannedWord(String wordId) async {
    await _supabase
        .from('banned_words')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', wordId);
  }
}

/// Model for banned word entries
class BannedWord {
  const BannedWord({
    required this.id,
    required this.word,
    required this.patternType,
    required this.severity,
    required this.language,
    required this.createdBy,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String word;
  final String patternType;
  final String severity;
  final String language;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;

  factory BannedWord.fromJson(Map<String, dynamic> json) {
    return BannedWord(
      id: json['id'] as String,
      word: json['word'] as String,
      patternType: json['pattern_type'] as String,
      severity: json['severity'] as String,
      language: json['language'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}
