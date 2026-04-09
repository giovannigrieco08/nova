import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/data/models/comment_report_model.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';

void main() {
  group('CommentReportModel', () {
    final now = DateTime(2025, 6, 1, 12, 0);
    final nowIso = now.toIso8601String();

    Map<String, dynamic> validJson({
      String id = 'report-001',
      String reason = 'spam',
      String? status,
      String? details,
      String? reviewedByModeratorId,
      String? reviewedAt,
      String? moderatorNotes,
    }) {
      return {
        'id': id,
        'comment_id': 'comment-001',
        'reporter_user_id': 'user-001',
        'reason': reason,
        'details': details,
        'status': status ?? 'pending',
        'reviewed_by_moderator_id': reviewedByModeratorId,
        'reviewed_at': reviewedAt,
        'moderator_notes': moderatorNotes,
        'created_at': nowIso,
      };
    }

    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('fromJson', () {
      test('deserializes all fields from JSON', () {
        final model = CommentReportModel.fromJson(validJson());

        expect(model.id, 'report-001');
        expect(model.commentId, 'comment-001');
        expect(model.reporterUserId, 'user-001');
        expect(model.reason, CommentReportReason.spam);
        expect(model.status, CommentReportStatus.pending);
        expect(model.details, isNull);
        expect(model.createdAt, now);
      });

      test('deserializes reviewed report with all optional fields', () {
        final reviewedAt = now.add(const Duration(hours: 2));
        final model = CommentReportModel.fromJson(validJson(
          reason: 'bullying',
          status: 'reviewed',
          details: 'Harassment in comment',
          reviewedByModeratorId: 'mod-001',
          reviewedAt: reviewedAt.toIso8601String(),
          moderatorNotes: 'Confirmed bullying',
        ));

        expect(model.reason, CommentReportReason.bullying);
        expect(model.status, CommentReportStatus.reviewed);
        expect(model.details, 'Harassment in comment');
        expect(model.reviewedByModeratorId, 'mod-001');
        expect(model.reviewedAt, reviewedAt);
        expect(model.moderatorNotes, 'Confirmed bullying');
      });

      test('deserializes all reason enum values', () {
        for (final reason in CommentReportReason.values) {
          final model = CommentReportModel.fromJson(
            validJson(reason: reason.value),
          );
          expect(model.reason, reason);
        }
      });
    });

    group('toJson', () {
      test('serializes all fields to snake_case JSON', () {
        final model = CommentReportModel.fromJson(validJson());
        final json = model.toJson();

        expect(json['id'], 'report-001');
        expect(json['comment_id'], 'comment-001');
        expect(json['reporter_user_id'], 'user-001');
        expect(json['reason'], 'spam');
        expect(json['status'], 'pending');
        expect(json['created_at'], nowIso);
      });
    });

    group('toInsertJson', () {
      test('excludes id and createdAt for database insert', () {
        final model = CommentReportModel.fromJson(validJson(
          details: 'Some details',
        ));
        final json = model.toInsertJson();

        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('created_at'), isFalse);
        expect(json.containsKey('status'), isFalse);
        expect(json['comment_id'], 'comment-001');
        expect(json['reporter_user_id'], 'user-001');
        expect(json['reason'], 'spam');
        expect(json['details'], 'Some details');
      });
    });

    group('entity conversion', () {
      test('toEntity creates CommentReport entity', () {
        final model = CommentReportModel.fromJson(validJson());
        final entity = model.toEntity();

        expect(entity, isA<CommentReport>());
        expect(entity.id, model.id);
        expect(entity.commentId, model.commentId);
        expect(entity.reason, model.reason);
        expect(entity.status, model.status);
      });

      test('fromEntity creates model from entity', () {
        final entity = CommentReport(
          id: 'r-1',
          commentId: 'c-1',
          reporterUserId: 'u-1',
          reason: CommentReportReason.inappropriate,
          status: CommentReportStatus.dismissed,
          createdAt: now,
        );

        final model = CommentReportModel.fromEntity(entity);
        expect(model.id, 'r-1');
        expect(model.reason, CommentReportReason.inappropriate);
        expect(model.status, CommentReportStatus.dismissed);
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('fromJson defaults status to pending when null', () {
        final json = validJson();
        json['status'] = null;
        final model = CommentReportModel.fromJson(json);
        expect(model.status, CommentReportStatus.pending);
      });

      test('fromJson handles unknown reason gracefully (defaults to other)', () {
        final model = CommentReportModel.fromJson(
          validJson(reason: 'totally_invalid'),
        );
        expect(model.reason, CommentReportReason.other);
      });

      test('copyWith returns new instance with updated fields', () {
        final model = CommentReportModel.fromJson(validJson());
        final updated = model.copyWith(
          status: CommentReportStatus.reviewed,
          reviewedByModeratorId: 'mod-001',
        );

        expect(updated.status, CommentReportStatus.reviewed);
        expect(updated.reviewedByModeratorId, 'mod-001');
        expect(updated.id, model.id); // unchanged
      });

      test('equality is based on id only', () {
        final a = CommentReportModel.fromJson(validJson(id: 'same'));
        final b = CommentReportModel.fromJson(validJson(id: 'same'));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different ids are not equal', () {
        final a = CommentReportModel.fromJson(validJson(id: 'id-1'));
        final b = CommentReportModel.fromJson(validJson(id: 'id-2'));
        expect(a, isNot(equals(b)));
      });

      test('roundtrip: fromJson -> toJson -> fromJson preserves data', () {
        final original = CommentReportModel.fromJson(validJson(
          reason: 'bullying',
          status: 'reviewed',
          details: 'Test details',
        ));
        final json = original.toJson();
        final restored = CommentReportModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.reason, original.reason);
        expect(restored.status, original.status);
        expect(restored.details, original.details);
      });

      test('toString contains key fields', () {
        final model = CommentReportModel.fromJson(validJson(
          reason: 'bullying',
          status: 'pending',
        ));
        final str = model.toString();
        expect(str, contains('report-001'));
        expect(str, contains('comment-001'));
        expect(str, contains('Bullismo/molestie'));
        expect(str, contains('In attesa'));
      });
    });
  });
}
