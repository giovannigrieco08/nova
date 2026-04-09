import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/admin/domain/entities/activity_log_entry.dart';

void main() {
  group('ActivityLogEntry', () {
    // ===================== HAPPY PATH =====================

    test('creates moderation action with all fields', () {
      final entry = ActivityLogEntry(
        id: 'log-001',
        type: 'moderation',
        actorId: 'mod-001',
        actorName: 'Prof Moderatore',
        action: 'approved',
        timestamp: DateTime(2025, 6, 1),
        eventId: 'evt-001',
        eventTitle: 'Test Event',
      );

      expect(entry.id, 'log-001');
      expect(entry.type, 'moderation');
      expect(entry.actorName, 'Prof Moderatore');
      expect(entry.action, 'approved');
      expect(entry.eventId, 'evt-001');
      expect(entry.eventTitle, 'Test Event');
      expect(entry.targetUserId, isNull);
    });

    test('creates admin action with all fields', () {
      final entry = ActivityLogEntry(
        id: 'log-002',
        type: 'admin',
        actorId: 'admin-001',
        actorName: 'Admin Nova',
        action: 'promoted',
        timestamp: DateTime(2025, 6, 1),
        targetUserId: 'user-001',
        targetUserName: 'Mario Rossi',
        oldRole: 'student',
        newRole: 'moderator',
      );

      expect(entry.type, 'admin');
      expect(entry.targetUserId, 'user-001');
      expect(entry.targetUserName, 'Mario Rossi');
      expect(entry.oldRole, 'student');
      expect(entry.newRole, 'moderator');
      expect(entry.eventId, isNull);
    });

    test('freezed equality compares all fields', () {
      final a = ActivityLogEntry(
        id: 'log-001',
        type: 'moderation',
        actorId: 'mod-001',
        actorName: 'Mod',
        action: 'approved',
        timestamp: DateTime(2025, 6, 1),
      );
      final b = ActivityLogEntry(
        id: 'log-001',
        type: 'moderation',
        actorId: 'mod-001',
        actorName: 'Mod',
        action: 'approved',
        timestamp: DateTime(2025, 6, 1),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ActivityLogEntryX extensions', () {
    // ===================== HAPPY PATH =====================

    test('isModerationAction and isAdminAction', () {
      final modEntry = ActivityLogEntry(
        id: '1',
        type: 'moderation',
        actorId: 'a',
        actorName: 'A',
        action: 'approved',
        timestamp: DateTime(2025, 1, 1),
      );
      final adminEntry = ActivityLogEntry(
        id: '2',
        type: 'admin',
        actorId: 'a',
        actorName: 'A',
        action: 'promoted',
        timestamp: DateTime(2025, 1, 1),
      );

      expect(modEntry.isModerationAction, true);
      expect(modEntry.isAdminAction, false);
      expect(adminEntry.isAdminAction, true);
      expect(adminEntry.isModerationAction, false);
    });

    test('actionDescription returns correct Italian text', () {
      ActivityLogEntry makeEntry(String action) => ActivityLogEntry(
            id: '1',
            type: 'moderation',
            actorId: 'a',
            actorName: 'A',
            action: action,
            timestamp: DateTime(2025, 1, 1),
          );

      expect(makeEntry('approved').actionDescription, 'Approvato evento');
      expect(makeEntry('rejected').actionDescription, 'Rifiutato evento');
      expect(makeEntry('promoted').actionDescription, 'Promosso a moderatore');
      expect(
          makeEntry('removed').actionDescription, 'Rimosso ruolo moderatore');
    });

    test('actionColor returns correct color key', () {
      ActivityLogEntry makeEntry(String action) => ActivityLogEntry(
            id: '1',
            type: 'moderation',
            actorId: 'a',
            actorName: 'A',
            action: action,
            timestamp: DateTime(2025, 1, 1),
          );

      expect(makeEntry('approved').actionColor, 'success');
      expect(makeEntry('rejected').actionColor, 'error');
      expect(makeEntry('promoted').actionColor, 'primary');
      expect(makeEntry('removed').actionColor, 'warning');
    });

    test('targetDescription returns event title or user name', () {
      final modEntry = ActivityLogEntry(
        id: '1',
        type: 'moderation',
        actorId: 'a',
        actorName: 'A',
        action: 'approved',
        timestamp: DateTime(2025, 1, 1),
        eventTitle: 'Festa di fine anno',
      );
      expect(modEntry.targetDescription, 'Festa di fine anno');

      final adminEntry = ActivityLogEntry(
        id: '2',
        type: 'admin',
        actorId: 'a',
        actorName: 'A',
        action: 'promoted',
        timestamp: DateTime(2025, 1, 1),
        targetUserName: 'Mario Rossi',
      );
      expect(adminEntry.targetDescription, 'Mario Rossi');
    });

    // ===================== EDGE CASES =====================

    test('actionDescription returns raw action for unknown values', () {
      final entry = ActivityLogEntry(
        id: '1',
        type: 'moderation',
        actorId: 'a',
        actorName: 'A',
        action: 'custom_action',
        timestamp: DateTime(2025, 1, 1),
      );
      expect(entry.actionDescription, 'custom_action');
    });

    test('actionColor returns secondary for unknown action', () {
      final entry = ActivityLogEntry(
        id: '1',
        type: 'moderation',
        actorId: 'a',
        actorName: 'A',
        action: 'unknown',
        timestamp: DateTime(2025, 1, 1),
      );
      expect(entry.actionColor, 'secondary');
    });

    test('targetDescription returns fallback when title/name is null', () {
      final modEntry = ActivityLogEntry(
        id: '1',
        type: 'moderation',
        actorId: 'a',
        actorName: 'A',
        action: 'approved',
        timestamp: DateTime(2025, 1, 1),
      );
      expect(modEntry.targetDescription, 'Evento sconosciuto');

      final adminEntry = ActivityLogEntry(
        id: '2',
        type: 'admin',
        actorId: 'a',
        actorName: 'A',
        action: 'promoted',
        timestamp: DateTime(2025, 1, 1),
      );
      expect(adminEntry.targetDescription, 'Utente sconosciuto');
    });
  });
}
