import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// SubscribeToRealtime Use Case
///
/// Subscribes to real-time comment updates for a specific event.
/// Uses Supabase Realtime WebSocket connection for instant updates.
///
/// Business Rules:
/// - Subscription is scoped to a single event
/// - Emits updated comment list on INSERT, UPDATE, DELETE
/// - Stream closes when disposed or on error
/// - Requires authenticated user
///
/// **FR-048**: Comments appear instantly without refresh
/// **Performance**: <500ms latency for real-time updates
///
/// Usage:
/// ```dart
/// final subscription = ref.read(subscribeToRealtimeProvider);
/// final stream = subscription(eventId: 'event-123');
///
/// stream.listen(
///   (comments) => updateUI(comments),
///   onError: (error) => showOfflineBanner(),
/// );
/// ```
class SubscribeToRealtime {
  final CommentsRepositoryInterface _repository;

  SubscribeToRealtime(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [eventId]: Event UUID to subscribe to
  ///
  /// Returns: Stream<List<Comment>> that emits on each change
  ///
  /// Stream Errors:
  /// - [NetworkException]: WebSocket connection failed
  /// - [UnauthorizedException]: User not authenticated
  /// - [ServerException]: Supabase Realtime error
  Stream<List<Comment>> call({required String eventId}) {
    return _repository.subscribeToComments(eventId: eventId);
  }
}
