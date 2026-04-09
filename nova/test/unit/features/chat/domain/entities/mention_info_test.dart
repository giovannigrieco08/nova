import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/domain/entities/mention_info.dart';

void main() {
  group('MentionInfo', () {
    // =========================================================
    // HAPPY PATH TESTS (H:2)
    // =========================================================

    test('creates mention with required fields and correct length', () {
      final mention = MentionInfo(
        userId: 'user-001',
        username: 'mario.rossi',
        startIndex: 5,
        endIndex: 17,
      );

      expect(mention.userId, 'user-001');
      expect(mention.username, 'mario.rossi');
      expect(mention.startIndex, 5);
      expect(mention.endIndex, 17);
      expect(mention.length, 12);
    });

    test('fromJson and toJson roundtrip', () {
      final json = {
        'user_id': 'user-002',
        'username': 'lucia.bianchi',
        'start_index': 0,
        'end_index': 14,
      };

      final mention = MentionInfo.fromJson(json);
      expect(mention.userId, 'user-002');
      expect(mention.username, 'lucia.bianchi');
      expect(mention.startIndex, 0);
      expect(mention.endIndex, 14);

      final output = mention.toJson();
      expect(output['user_id'], 'user-002');
      expect(output['username'], 'lucia.bianchi');
      expect(output['start_index'], 0);
      expect(output['end_index'], 14);
    });

    // =========================================================
    // EDGE CASE TESTS (E:2)
    // =========================================================

    test('equality is based on userId and startIndex', () {
      final m1 = MentionInfo(
        userId: 'user-001',
        username: 'mario.rossi',
        startIndex: 5,
        endIndex: 17,
      );
      final m2 = MentionInfo(
        userId: 'user-001',
        username: 'different.name', // different
        startIndex: 5,
        endIndex: 20, // different
      );

      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
    });

    test('mentions with different startIndex are not equal', () {
      final m1 = MentionInfo(
        userId: 'user-001',
        username: 'mario.rossi',
        startIndex: 0,
        endIndex: 12,
      );
      final m2 = MentionInfo(
        userId: 'user-001',
        username: 'mario.rossi',
        startIndex: 20,
        endIndex: 32,
      );

      expect(m1, isNot(equals(m2)));
    });

    test('length is zero when startIndex equals endIndex', () {
      final mention = MentionInfo(
        userId: 'user-001',
        username: '',
        startIndex: 5,
        endIndex: 5,
      );
      expect(mention.length, 0);
    });
  });
}
