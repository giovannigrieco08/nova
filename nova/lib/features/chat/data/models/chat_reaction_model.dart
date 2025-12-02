import 'package:nova/features/chat/domain/entities/chat_reaction.dart';

/// Data model for ChatReaction with JSON serialization.
class ChatReactionModel {
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const ChatReactionModel({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  /// Create from Supabase JSON response
  factory ChatReactionModel.fromJson(Map<String, dynamic> json) {
    return ChatReactionModel(
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON for insert
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    };
  }

  /// Create insert payload
  static Map<String, dynamic> toInsertJson({
    required String messageId,
    required String userId,
    required String emoji,
  }) {
    return {
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    };
  }

  /// Convert to domain entity
  ChatReaction toEntity() {
    return ChatReaction(
      messageId: messageId,
      userId: userId,
      emoji: emoji,
      createdAt: createdAt,
    );
  }

  /// Create from domain entity
  factory ChatReactionModel.fromEntity(ChatReaction entity) {
    return ChatReactionModel(
      messageId: entity.messageId,
      userId: entity.userId,
      emoji: entity.emoji,
      createdAt: entity.createdAt,
    );
  }
}
