import '../../data/models/content_check_result.dart';
import '../../data/repositories/content_filter_repository.dart';

/// Service for content filtering operations
///
/// Provides content validation before submission
class ContentFilterService {
  ContentFilterService({ContentFilterRepository? repository})
      : _repository = repository ?? ContentFilterRepository();

  final ContentFilterRepository _repository;

  /// Check if content is allowed
  ///
  /// Returns ContentCheckResult with allowed/blocked status
  Future<ContentCheckResult> checkContent(String text) async {
    // Skip check for very short text
    if (text.trim().length < 3) {
      return ContentCheckResult.clean();
    }

    return _repository.checkContent(text);
  }

  /// Validate content before submission
  ///
  /// Throws ContentBlockedException if blocked
  Future<void> validateContent(String text) async {
    final result = await checkContent(text);

    if (result.blocked) {
      throw ContentBlockedException(
        matchedWords: result.matchedWords,
      );
    }
  }

  /// Check if content is clean (no issues)
  Future<bool> isContentClean(String text) async {
    final result = await checkContent(text);
    return result.isClean;
  }

  /// Get banned words list (for moderators)
  Future<List<BannedWord>> getBannedWords({String? language}) async {
    return _repository.getBannedWords(language: language);
  }
}

/// Exception thrown when content contains blocked words
class ContentBlockedException implements Exception {
  const ContentBlockedException({
    this.matchedWords = const [],
  });

  final List<String> matchedWords;

  @override
  String toString() => 'Il contenuto contiene linguaggio non consentito';
}
