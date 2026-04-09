import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/safety/data/models/user_sanction.dart';

void main() {
  group('SanctionType', () {
    test('fromString parses known values', () {
      expect(SanctionType.fromString('warning'), SanctionType.warning);
      expect(SanctionType.fromString('suspension'), SanctionType.suspension);
      expect(SanctionType.fromString('ban'), SanctionType.ban);
    });

    test('fromString defaults to warning for unknown value', () {
      expect(SanctionType.fromString('unknown'), SanctionType.warning);
    });

    test('displayName returns Italian labels', () {
      expect(SanctionType.warning.displayName, 'Avvertimento');
      expect(SanctionType.suspension.displayName, 'Sospensione');
      expect(SanctionType.ban.displayName, 'Ban permanente');
    });
  });

  group('UserSanction', () {
    final now = DateTime.now();

    UserSanction createSanction({
      String id = 'sanction-001',
      String userId = 'user-001',
      SanctionType type = SanctionType.warning,
      String reason = 'Comportamento inappropriato',
      String issuedBy = 'mod-001',
      DateTime? issuedAt,
      DateTime? expiresAt,
      DateTime? liftedAt,
      String? liftedBy,
    }) {
      return UserSanction(
        id: id,
        userId: userId,
        type: type,
        reason: reason,
        issuedBy: issuedBy,
        issuedAt: issuedAt ?? now,
        expiresAt: expiresAt,
        liftedAt: liftedAt,
        liftedBy: liftedBy,
      );
    }

    // ===================== HAPPY PATH =====================

    test('creates with required fields', () {
      final sanction = createSanction();

      expect(sanction.id, 'sanction-001');
      expect(sanction.userId, 'user-001');
      expect(sanction.type, SanctionType.warning);
      expect(sanction.reason, 'Comportamento inappropriato');
      expect(sanction.issuedBy, 'mod-001');
      expect(sanction.isActive, true);
    });

    test('fromJson parses complete sanction JSON', () {
      final json = {
        'id': 's1',
        'user_id': 'u1',
        'type': 'suspension',
        'reason': 'Spam',
        'related_report_id': 'report-001',
        'related_content_type': 'comment',
        'related_content_id': 'comment-001',
        'issued_by': 'mod-001',
        'issued_at': '2025-06-01T10:00:00.000Z',
        'expires_at': '2025-07-01T10:00:00.000Z',
        'lifted_at': null,
        'lifted_by': null,
        'issued_by_user': {
          'full_name': 'Moderatore',
          'username': 'mod.user',
        },
      };

      final sanction = UserSanction.fromJson(json);

      expect(sanction.type, SanctionType.suspension);
      expect(sanction.relatedReportId, 'report-001');
      expect(sanction.relatedContentType, 'comment');
      expect(sanction.issuedByUser, isNotNull);
      expect(sanction.issuedByUser!.fullName, 'Moderatore');
    });

    test('isActive, isExpired, wasLifted computed correctly for active sanction',
        () {
      final sanction = createSanction(
        expiresAt: now.add(const Duration(days: 30)),
      );

      expect(sanction.isActive, true);
      expect(sanction.isExpired, false);
      expect(sanction.wasLifted, false);
    });

    // ===================== EDGE CASES =====================

    test('isActive returns false when lifted', () {
      final sanction = createSanction(
        liftedAt: now,
        liftedBy: 'admin-001',
      );

      expect(sanction.isActive, false);
      expect(sanction.wasLifted, true);
    });

    test('isExpired returns true when past expiresAt and not lifted', () {
      final sanction = createSanction(
        expiresAt: now.subtract(const Duration(days: 1)),
      );

      expect(sanction.isExpired, true);
      expect(sanction.isActive, false);
    });

    test('equality is based on id', () {
      final a = createSanction(id: 's1');
      final b = createSanction(id: 's1', reason: 'Different');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('permanent ban (no expiresAt) stays active', () {
      final sanction = createSanction(type: SanctionType.ban);

      expect(sanction.isActive, true);
      expect(sanction.isExpired, false);
    });
  });

  group('SanctionIssuerInfo', () {
    test('fromJson parses correctly', () {
      final info = SanctionIssuerInfo.fromJson({
        'full_name': 'Admin User',
        'username': 'admin.user',
      });

      expect(info.fullName, 'Admin User');
      expect(info.username, 'admin.user');
    });

    test('fromJson handles null username', () {
      final info = SanctionIssuerInfo.fromJson({
        'full_name': 'Admin',
      });

      expect(info.username, isNull);
    });
  });
}
