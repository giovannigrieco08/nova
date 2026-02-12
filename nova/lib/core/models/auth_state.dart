// =====================================================================
// Nova - Authentication State Model
// =====================================================================
// Purpose: Sealed class hierarchy for authentication states
// Architecture: Dart 3.x sealed classes with pattern matching support
// =====================================================================

import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication state sealed class hierarchy
///
/// Represents all possible authentication states in the app using
/// Dart 3.x sealed classes for exhaustive pattern matching.
///
/// States:
/// - [AuthStateAuthenticated]: User is logged in
/// - [AuthStateUnauthenticated]: User is not logged in
/// - [AuthStateLoading]: Authentication operation in progress
/// - [AuthStateError]: Authentication error occurred
///
/// Usage with pattern matching:
/// ```dart
/// switch (authState) {
///   case AuthStateAuthenticated(:final user):
///     print('Logged in as ${user.email}');
///   case AuthStateUnauthenticated():
///     // Show login screen
///   case AuthStateLoading():
///     // Show loading indicator
///   case AuthStateError(:final message):
///     // Show error message
/// }
/// ```
sealed class AuthState {
  const AuthState();
}

/// User is authenticated with valid session
///
/// Contains the current [User] object from Supabase.
///
/// Access user data:
/// ```dart
/// if (state case AuthStateAuthenticated(:final user)) {
///   print(user.email);
///   print(user.id);
///   print(user.createdAt);
/// }
/// ```
final class AuthStateAuthenticated extends AuthState {
  /// Current authenticated user
  final User user;

  const AuthStateAuthenticated(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateAuthenticated &&
          runtimeType == other.runtimeType &&
          user.id == other.user.id;

  @override
  int get hashCode => user.id.hashCode;

  @override
  String toString() => 'AuthStateAuthenticated(userId: ${user.id})';
}

/// User is not authenticated (no active session)
///
/// Represents the default state when:
/// - App starts without saved session
/// - User logs out manually
/// - Session expires
///
/// Example:
/// ```dart
/// if (state is AuthStateUnauthenticated) {
///   // Navigate to login screen
/// }
/// ```
final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateUnauthenticated && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthStateUnauthenticated()';
}

/// Authentication operation in progress
///
/// Used during:
/// - Magic link request being sent
/// - Token verification
/// - Sign out operation
/// - Session restoration
///
/// Example:
/// ```dart
/// if (state is AuthStateLoading) {
///   // Show loading spinner
/// }
/// ```
final class AuthStateLoading extends AuthState {
  /// Optional message describing what's loading
  final String? message;

  const AuthStateLoading([this.message]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateLoading &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AuthStateLoading(message: $message)';
}

/// User is browsing as guest (Apple Guideline 5.1.1 compliance)
///
/// App starts in this state by default. Users can browse events
/// without logging in. Login is only required for interactions.
///
/// Guest users can:
/// - View approved events
/// - View event details
/// - See like/participation counts
///
/// Guest users cannot (prompts login):
/// - Like events
/// - Participate in events
/// - Post comments
/// - Access profile features
final class AuthStateGuest extends AuthState {
  const AuthStateGuest();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateGuest && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthStateGuest()';
}

/// Authentication error occurred
///
/// Contains error [message] to display to user.
///
/// Common error scenarios:
/// - Invalid email format
/// - Rate limit exceeded (3 per 15 min)
/// - Magic link expired (15 min)
/// - Network connectivity issues
/// - Supabase backend errors
///
/// Example:
/// ```dart
/// if (state case AuthStateError(:final message)) {
///   showDialog(
///     context: context,
///     builder: (_) => AlertDialog(
///       title: Text('Error'),
///       content: Text(message),
///     ),
///   );
/// }
/// ```
final class AuthStateError extends AuthState {
  /// User-friendly error message
  final String message;

  const AuthStateError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AuthStateError(message: $message)';
}
