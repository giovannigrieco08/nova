// =====================================================================
// EventHelpRequest Entity (Freezed)
// Purpose: Immutable entity representing a help request for an event
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_help_request.freezed.dart';
part 'event_help_request.g.dart';

/// Help request created by event organizers
///
/// Allows event creators to ask for help from other students
/// (e.g., "Looking for photographer", "Need someone for graphics")
@freezed
class EventHelpRequest with _$EventHelpRequest {
  const EventHelpRequest._();

  const factory EventHelpRequest({
    /// Unique request ID (UUID)
    required String id,

    /// Event this request belongs to
    required String eventId,

    /// Free-text description of help needed
    required String description,

    /// Whether someone's offer has been accepted
    @Default(false) bool isFulfilled,

    /// User who fulfilled the request (accepted offer)
    String? fulfilledBy,

    /// When the request was created
    required DateTime createdAt,

    /// When the request was last updated
    required DateTime updatedAt,

    /// Number of pending offers (computed from offers list)
    @Default(0) int pendingOffersCount,
  }) = _EventHelpRequest;

  factory EventHelpRequest.fromJson(Map<String, dynamic> json) =>
      _$EventHelpRequestFromJson(json);

  /// Check if request is still open (not fulfilled)
  bool get isOpen => !isFulfilled;
}

/// Offer from a student to help with a request
@freezed
class EventHelpOffer with _$EventHelpOffer {
  const EventHelpOffer._();

  const factory EventHelpOffer({
    /// Unique offer ID (UUID)
    required String id,

    /// Request this offer is for
    required String requestId,

    /// User who made the offer
    required String userId,

    /// Optional message from the user
    String? message,

    /// Status: pending, accepted, declined
    @Default('pending') String status,

    /// When the offer was created
    required DateTime createdAt,

    /// When the offer was last updated
    required DateTime updatedAt,

    // ========================================================================
    // USER INFO (from joined profile data)
    // ========================================================================

    /// User's display name (from profiles.full_name)
    String? userName,

    /// User's class (from profiles.class)
    String? userClass,

    /// User's avatar URL (from profiles.avatar_url)
    String? userAvatarUrl,
  }) = _EventHelpOffer;

  factory EventHelpOffer.fromJson(Map<String, dynamic> json) =>
      _$EventHelpOfferFromJson(json);

  /// Check if offer is pending
  bool get isPending => status == 'pending';

  /// Check if offer was accepted
  bool get isAccepted => status == 'accepted';

  /// Check if offer was declined
  bool get isDeclined => status == 'declined';
}

/// Status values for help offers
class HelpOfferStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';

  HelpOfferStatus._();
}
