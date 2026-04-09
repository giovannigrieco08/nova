import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/data/models/chat_report_model.dart';
import 'package:nova/features/chat/domain/entities/chat_report.dart';

void main() {
  group('ChatReportModel', () {
    final validJson = {
      'id': 'report-001',
      'message_id': 'msg-001',
      'reporter_user_id': 'user-001',
      'reason': 'bullying',
      'status': 'pending',
      'created_at': '2025-06-15T10:00:00.000Z',
    };

    final fullJson = {
      ...validJson,
      'status': 'reviewed',
      'reviewed_by_moderator_id': 'mod-001',
      'reviewed_at': '2025-06-15T12:00:00.000Z',
      'moderator_notes': 'Confermato bullismo',
    };

    // =========================================================
    // HAPPY PATH TESTS (H:2)
    // =========================================================

    test('fromJson parses minimal valid JSON correctly', () {
      final model = ChatReportModel.fromJson(validJson);

      expect(model.id, 'report-001');
      expect(model.messageId, 'msg-001');
      expect(model.reporterUserId, 'user-001');
      expect(model.reason, 'bullying');
      expect(model.status, 'pending');
      expect(model.createdAt, DateTime.utc(2025, 6, 15, 10, 0));
      expect(model.reviewedByModeratorId, isNull);
      expect(model.reviewedAt, isNull);
      expect(model.moderatorNotes, isNull);
    });

    test('toJson and toEntity produce correct output', () {
      final model = ChatReportModel.fromJson(fullJson);

      // toJson
      final json = model.toJson();
      expect(json['id'], 'report-001');
      expect(json['message_id'], 'msg-001');
      expect(json['reporter_user_id'], 'user-001');
      expect(json['reason'], 'bullying');
      expect(json['status'], 'reviewed');

      // toEntity
      final entity = model.toEntity();
      expect(entity, isA<ChatReport>());
      expect(entity.id, 'report-001');
      expect(entity.reason, ChatReportReason.bullying);
      expect(entity.status, ChatReportStatus.reviewed);
      expect(entity.reviewedByModeratorId, 'mod-001');
      expect(entity.moderatorNotes, 'Confermato bullismo');
      expect(entity.isReviewed, isTrue);
    });

    // =========================================================
    // EDGE CASE TESTS (E:2)
    // =========================================================

    test('fromJson defaults status to pending when missing', () {
      final json = {
        'id': 'report-002',
        'message_id': 'msg-002',
        'reporter_user_id': 'user-002',
        'reason': 'spam',
        'created_at': '2025-06-15T10:00:00.000Z',
        // no status
      };

      final model = ChatReportModel.fromJson(json);
      expect(model.status, 'pending');

      final entity = model.toEntity();
      expect(entity.status, ChatReportStatus.pending);
      expect(entity.isReviewed, isFalse);
    });

    test('fromEntity and back to entity roundtrip preserves data', () {
      final entity = ChatReport(
        id: 'report-003',
        messageId: 'msg-003',
        reporterUserId: 'user-003',
        reason: ChatReportReason.offTopic,
        status: ChatReportStatus.dismissed,
        reviewedByModeratorId: 'mod-002',
        reviewedAt: DateTime.utc(2025, 7, 1, 14, 30),
        moderatorNotes: 'Non pertinente',
        createdAt: DateTime.utc(2025, 7, 1, 10, 0),
      );

      final model = ChatReportModel.fromEntity(entity);
      expect(model.reason, 'off_topic');
      expect(model.status, 'dismissed');

      final backToEntity = model.toEntity();
      expect(backToEntity.id, entity.id);
      expect(backToEntity.reason, entity.reason);
      expect(backToEntity.status, entity.status);
      expect(backToEntity.reviewedByModeratorId, entity.reviewedByModeratorId);
      expect(backToEntity.moderatorNotes, entity.moderatorNotes);
    });

    test('toInsertJson creates correct payload with reason value', () {
      final json = ChatReportModel.toInsertJson(
        messageId: 'msg-004',
        reporterUserId: 'user-004',
        reason: ChatReportReason.inappropriate,
      );

      expect(json['message_id'], 'msg-004');
      expect(json['reporter_user_id'], 'user-004');
      expect(json['reason'], 'inappropriate');
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });
  });
}
