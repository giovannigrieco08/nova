import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/safety/data/models/user_block.dart';

void main() {
  group('UserBlock', () {
    // ===================== HAPPY PATH =====================

    test('creates with required fields', () {
      final block = UserBlock(
        id: 'block-001',
        blockerId: 'user-001',
        blockedId: 'user-002',
        createdAt: DateTime(2025, 6, 1),
      );

      expect(block.id, 'block-001');
      expect(block.blockerId, 'user-001');
      expect(block.blockedId, 'user-002');
      expect(block.moderatorNotified, false);
      expect(block.notifiedAt, isNull);
      expect(block.blockedUser, isNull);
    });

    test('fromJson parses complete JSON with blocked user join', () {
      final json = {
        'id': 'block-001',
        'blocker_id': 'user-001',
        'blocked_id': 'user-002',
        'created_at': '2025-06-01T10:00:00.000Z',
        'moderator_notified': true,
        'notified_at': '2025-06-01T12:00:00.000Z',
        'blocked': {
          'user_id': 'user-002',
          'full_name': 'Mario Rossi',
          'username': 'mario.rossi',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };

      final block = UserBlock.fromJson(json);

      expect(block.id, 'block-001');
      expect(block.moderatorNotified, true);
      expect(block.notifiedAt, isNotNull);
      expect(block.blockedUser, isNotNull);
      expect(block.blockedUser!.fullName, 'Mario Rossi');
      expect(block.blockedUser!.username, 'mario.rossi');
    });

    test('toJson returns only blocker and blocked IDs', () {
      final block = UserBlock(
        id: 'block-001',
        blockerId: 'user-001',
        blockedId: 'user-002',
        createdAt: DateTime(2025, 6, 1),
      );

      final json = block.toJson();

      expect(json, {
        'blocker_id': 'user-001',
        'blocked_id': 'user-002',
      });
      expect(json.containsKey('id'), false);
      expect(json.containsKey('created_at'), false);
    });

    test('equality is based on id', () {
      final a = UserBlock(
        id: 'block-001',
        blockerId: 'u1',
        blockedId: 'u2',
        createdAt: DateTime(2025, 1, 1),
      );
      final b = UserBlock(
        id: 'block-001',
        blockerId: 'u3',
        blockedId: 'u4',
        createdAt: DateTime(2025, 6, 1),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    // ===================== EDGE CASES =====================

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'block-001',
        'blocker_id': 'user-001',
        'blocked_id': 'user-002',
        'created_at': '2025-06-01T00:00:00.000Z',
      };

      final block = UserBlock.fromJson(json);

      expect(block.moderatorNotified, false);
      expect(block.notifiedAt, isNull);
      expect(block.blockedUser, isNull);
    });

    test('fromJson handles null moderator_notified as false', () {
      final json = {
        'id': 'block-001',
        'blocker_id': 'user-001',
        'blocked_id': 'user-002',
        'created_at': '2025-06-01T00:00:00.000Z',
        'moderator_notified': null,
      };

      final block = UserBlock.fromJson(json);
      expect(block.moderatorNotified, false);
    });
  });

  group('BlockedUserInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'user_id': 'u1',
        'full_name': 'Test User',
        'username': 'test.user',
        'avatar_url': 'https://example.com/a.jpg',
      };

      final info = BlockedUserInfo.fromJson(json);

      expect(info.userId, 'u1');
      expect(info.fullName, 'Test User');
      expect(info.username, 'test.user');
      expect(info.avatarUrl, 'https://example.com/a.jpg');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'user_id': 'u1',
        'full_name': 'Test',
      };

      final info = BlockedUserInfo.fromJson(json);
      expect(info.username, isNull);
      expect(info.avatarUrl, isNull);
    });
  });
}
