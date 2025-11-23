import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';
import '../exceptions/comments_exceptions.dart';

/// Use Case: Post Comment
///
/// Creates a new top-level comment on an event.
/// Validates text, handles profanity filter, and enforces rate limits.
///
/// Business Rules:
/// - Text must be 1-500 characters after trim
/// - Profanity filter applied server-side (150+ Italian words)
/// - Rate limit: Max 3 identical comments in 5 minutes
/// - User must be authenticated
/// - Event must be approved (not pending/rejected)
///
/// Constitutional Principle 5 (SPEC_FIRST): Use cases enforce business rules
/// before calling repository methods. Validation happens at both client and server.
class PostComment {
  final CommentsRepositoryInterface _repository;

  PostComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [eventId]: Event UUID to comment on
  /// - [text]: Comment text (will be trimmed)
  ///
  /// Returns: Created Comment entity with server-generated UUID
  ///
  /// Throws:
  /// - [ValidationException]: Text length invalid (client-side validation)
  /// - [ValidationException]: Text contains profanity (server-side validation)
  /// - [RateLimitException]: User exceeded rate limit (3 identical in 5 min)
  /// - [NetworkException]: Network error or timeout
  /// - [UnauthorizedException]: User not authenticated
  /// - [ForbiddenException]: Event not approved or user not allowed to comment
  /// - [NotFoundException]: Event does not exist
  /// - [ServerException]: Supabase error (5xx)
  Future<Comment> call({
    required String eventId,
    required String text,
  }) async {
    // Client-side validation (fast fail before network call)
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw const ValidationException(
        'Il commento non può essere vuoto',
        'text',
        null,
      );
    }

    if (trimmedText.length > 500) {
      throw ValidationException(
        'Il commento non può superare i 500 caratteri (attuale: ${trimmedText.length})',
        'text',
        trimmedText.length,
      );
    }

    // Call repository (server-side validation + storage)
    return await _repository.postComment(
      eventId: eventId,
      text: trimmedText,
    );
  }
}
