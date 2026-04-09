import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/admin/data/models/admin_action.dart';

void main() {
  group('AdminAction', () {
    // ===================== HAPPY PATH =====================

    test('creates with all required fields', () {
      final action = AdminAction(
        id: 'action-001',
        adminId: 'admin-001',
        targetUserId: 'user-001',
        action: 'promote_to_moderator',
        timestamp: DateTime(2025, 6, 1),
        notes: 'Promoted by admin',
      );

      expect(action.id, 'action-001');
      expect(action.adminId, 'admin-001');
      expect(action.targetUserId, 'user-001');
      expect(action.action, 'promote_to_moderator');
      expect(action.notes, 'Promoted by admin');
      expect(action.timestamp, DateTime(2025, 6, 1));
    });

    test('freezed equality compares all fields', () {
      final a = AdminAction(
        id: 'a1',
        adminId: 'admin',
        targetUserId: 'user',
        action: 'promote_to_moderator',
        timestamp: DateTime(2025, 1, 1),
      );
      final b = AdminAction(
        id: 'a1',
        adminId: 'admin',
        targetUserId: 'user',
        action: 'promote_to_moderator',
        timestamp: DateTime(2025, 1, 1),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    // ===================== EDGE CASES =====================

    test('notes defaults to null when not provided', () {
      final action = AdminAction(
        id: 'a1',
        adminId: 'admin',
        targetUserId: 'user',
        action: 'remove_moderator_role',
        timestamp: DateTime(2025, 1, 1),
      );

      expect(action.notes, isNull);
    });
  });
}
