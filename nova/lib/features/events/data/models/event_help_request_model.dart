// =====================================================================
// EventHelpRequestModel - Data layer model
// Purpose: Handles JSON serialization and conversion to domain entity
// =====================================================================

import '../../domain/entities/event_help_request.dart';

/// Data model for EventHelpRequest
class EventHelpRequestModel {
  final String id;
  final String eventId;
  final String description;
  final bool isFulfilled;
  final String? fulfilledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int pendingOffersCount;

  EventHelpRequestModel({
    required this.id,
    required this.eventId,
    required this.description,
    this.isFulfilled = false,
    this.fulfilledBy,
    required this.createdAt,
    required this.updatedAt,
    this.pendingOffersCount = 0,
  });

  /// Create from JSON (Supabase response)
  factory EventHelpRequestModel.fromJson(Map<String, dynamic> json) {
    return EventHelpRequestModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      description: json['description'] as String,
      isFulfilled: json['is_fulfilled'] as bool? ?? false,
      fulfilledBy: json['fulfilled_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      pendingOffersCount: json['pending_offers_count'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'description': description,
      'is_fulfilled': isFulfilled,
      'fulfilled_by': fulfilledBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to domain entity
  EventHelpRequest toEntity() {
    return EventHelpRequest(
      id: id,
      eventId: eventId,
      description: description,
      isFulfilled: isFulfilled,
      fulfilledBy: fulfilledBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pendingOffersCount: pendingOffersCount,
    );
  }

  /// Create from domain entity
  factory EventHelpRequestModel.fromEntity(EventHelpRequest entity) {
    return EventHelpRequestModel(
      id: entity.id,
      eventId: entity.eventId,
      description: entity.description,
      isFulfilled: entity.isFulfilled,
      fulfilledBy: entity.fulfilledBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      pendingOffersCount: entity.pendingOffersCount,
    );
  }
}

/// Data model for EventHelpOffer
class EventHelpOfferModel {
  final String id;
  final String requestId;
  final String userId;
  final String? message;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;
  final String? userClass;
  final String? userAvatarUrl;

  EventHelpOfferModel({
    required this.id,
    required this.requestId,
    required this.userId,
    this.message,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userClass,
    this.userAvatarUrl,
  });

  /// Create from JSON (Supabase response with joined profile)
  factory EventHelpOfferModel.fromJson(Map<String, dynamic> json) {
    // Handle joined profile data
    final profile = json['profile'] as Map<String, dynamic>?;

    return EventHelpOfferModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: profile?['full_name'] as String?,
      userClass: profile?['class'] as String?,
      userAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'user_id': userId,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to domain entity
  EventHelpOffer toEntity() {
    return EventHelpOffer(
      id: id,
      requestId: requestId,
      userId: userId,
      message: message,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userName: userName,
      userClass: userClass,
      userAvatarUrl: userAvatarUrl,
    );
  }

  /// Create from domain entity
  factory EventHelpOfferModel.fromEntity(EventHelpOffer entity) {
    return EventHelpOfferModel(
      id: entity.id,
      requestId: entity.requestId,
      userId: entity.userId,
      message: entity.message,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      userName: entity.userName,
      userClass: entity.userClass,
      userAvatarUrl: entity.userAvatarUrl,
    );
  }
}
