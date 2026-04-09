import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/collaboration_invite.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('CollaborationInvite', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create CollaborationInvite with required fields and defaults', () {
      final invite = CollaborationInvite(
        id: 'invite-001',
        eventId: 'event-001',
        inviterId: 'user-001',
        inviteeId: 'user-002',
        createdAt: now,
      );

      expect(invite.id, 'invite-001');
      expect(invite.eventId, 'event-001');
      expect(invite.inviterId, 'user-001');
      expect(invite.inviteeId, 'user-002');
      expect(invite.status, CollaborationInviteStatus.pending);
      expect(invite.respondedAt, isNull);
      expect(invite.message, isNull);
    });

    test('status getters return correct values', () {
      final pending = CollaborationInvite(
        id: 'i1',
        eventId: 'e1',
        inviterId: 'u1',
        inviteeId: 'u2',
        createdAt: now,
        status: CollaborationInviteStatus.pending,
      );

      final accepted = pending.copyWith(status: CollaborationInviteStatus.accepted);
      final declined = pending.copyWith(status: CollaborationInviteStatus.declined);

      expect(pending.isPending, isTrue);
      expect(pending.isAccepted, isFalse);
      expect(pending.isDeclined, isFalse);

      expect(accepted.isAccepted, isTrue);
      expect(accepted.isPending, isFalse);

      expect(declined.isDeclined, isTrue);
      expect(declined.isPending, isFalse);
    });

    test('fromJson and toJson roundtrip preserves data', () {
      final invite = CollaborationInvite(
        id: 'invite-001',
        eventId: 'event-001',
        inviterId: 'user-001',
        inviteeId: 'user-002',
        status: CollaborationInviteStatus.accepted,
        createdAt: now,
        respondedAt: now.add(const Duration(hours: 1)),
        message: 'Join my event!',
      );

      final json = invite.toJson();
      final restored = CollaborationInvite.fromJson(json);

      expect(restored.id, invite.id);
      expect(restored.eventId, invite.eventId);
      expect(restored.inviterId, invite.inviterId);
      expect(restored.inviteeId, invite.inviteeId);
      expect(restored.status, invite.status);
      expect(restored.message, invite.message);
      expect(restored.respondedAt, isNotNull);
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('fromJson defaults to pending when status is unknown', () {
      final json = {
        'id': 'invite-001',
        'event_id': 'event-001',
        'inviter_id': 'user-001',
        'invitee_id': 'user-002',
        'status': 'unknown_status',
        'created_at': now.toIso8601String(),
      };

      final invite = CollaborationInvite.fromJson(json);
      expect(invite.status, CollaborationInviteStatus.pending);
    });

    test('toJson omits null optional fields', () {
      final invite = CollaborationInvite(
        id: 'invite-001',
        eventId: 'event-001',
        inviterId: 'user-001',
        inviteeId: 'user-002',
        createdAt: now,
      );

      final json = invite.toJson();

      expect(json.containsKey('responded_at'), isFalse);
      expect(json.containsKey('message'), isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      final invite = CollaborationInvite(
        id: 'invite-001',
        eventId: 'event-001',
        inviterId: 'user-001',
        inviteeId: 'user-002',
        createdAt: now,
        message: 'Hello',
      );

      final updated = invite.copyWith(
        status: CollaborationInviteStatus.accepted,
        respondedAt: now.add(const Duration(hours: 2)),
      );

      expect(updated.id, invite.id);
      expect(updated.eventId, invite.eventId);
      expect(updated.message, 'Hello');
      expect(updated.status, CollaborationInviteStatus.accepted);
      expect(updated.respondedAt, isNotNull);
    });
  });
}
