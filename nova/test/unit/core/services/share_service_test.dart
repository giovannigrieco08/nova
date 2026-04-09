/// Tests for ShareService
///
/// Tests ShareException behavior, error propagation, and shareProfileInChat
/// callback logic. Direct testing of URL generation and Share.share() calls
/// is limited because:
/// - URL generation helpers are private static methods
/// - They depend on SupabaseConfig which requires --dart-define at compile time
/// - Share.share() throws MissingPluginException in test environment

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/services/share_service.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';

void main() {
  group('ShareService', () {
    // =========================================================================
    // ShareException
    // =========================================================================

    group('ShareException', () {
      test('stores message correctly', () {
        final exception = ShareException('Test failure');

        expect(exception.message, equals('Test failure'));
      });

      test('toString includes class prefix and message', () {
        final exception = ShareException('share failed');

        expect(exception.toString(), equals('ShareException: share failed'));
      });

      test('implements Exception interface', () {
        final exception = ShareException('test');

        expect(exception, isA<Exception>());
      });

      test('handles empty message', () {
        final exception = ShareException('');

        expect(exception.message, isEmpty);
        expect(exception.toString(), equals('ShareException: '));
      });

      test('preserves special characters in message', () {
        final exception = ShareException('Failed: "event" <title> & more');

        expect(exception.message, equals('Failed: "event" <title> & more'));
      });
    });

    // =========================================================================
    // Instance creation
    // =========================================================================

    group('instance creation', () {
      test('default constructor creates instance for profile sharing', () {
        final service = ShareService();

        expect(service, isNotNull);
        expect(service, isA<ShareService>());
      });
    });

    // =========================================================================
    // shareEvent - error propagation
    // =========================================================================

    group('shareEvent', () {
      test('throws when SupabaseConfig is not configured', () {
        // Without --dart-define=SUPABASE_URL, _baseUrl throws before
        // Share.share() is ever called. The exception from SupabaseConfig
        // propagates directly (not wrapped in ShareException) because
        // _generateEventDeepLink is called outside the try block.
        final event = Event(
          id: 'test-event-001',
          title: 'Torneo di Calcetto',
          description: 'Partita di calcetto tra classi.',
          creatorId: 'creator-001',
          eventDate: DateTime(2025, 3, 15, 14, 30),
          status: EventStatus.approved,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        expect(
          () => ShareService.shareEvent(event),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareEventDetailed - error propagation
    // =========================================================================

    group('shareEventDetailed', () {
      test('throws when SupabaseConfig is not configured', () {
        final event = Event(
          id: 'test-event-002',
          title: 'Giornata della Scienza',
          description: 'Esperimenti e dimostrazioni scientifiche '
              'organizzate dalla classe 5A per tutti gli studenti.',
          creatorId: 'creator-001',
          eventDate: DateTime(2025, 4, 20, 10, 0),
          location: 'Laboratorio di Fisica',
          status: EventStatus.approved,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        expect(
          () => ShareService.shareEventDetailed(event),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareProfileInChat - callback logic
    // =========================================================================

    group('shareProfileInChat', () {
      late ShareService service;

      setUp(() {
        service = ShareService();
      });

      test('throws when SupabaseConfig is not configured', () {
        // shareProfileInChat calls _generateProfileDeepLink which uses
        // _baseUrl -> SupabaseConfig.supabaseUrl, throwing without dart-define
        final profile = Profile(
          userId: 'user-001',
          email: 'mario.rossi@galileimoro.edu.it',
          fullName: 'Mario Rossi',
          username: 'mario.rossi',
          classYear: '4A',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        expect(
          () => service.shareProfileInChat(
            profile,
            onNavigateToChat: (_) {},
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareProfile - error propagation
    // =========================================================================

    group('shareProfile', () {
      test('throws when SupabaseConfig is not configured', () {
        final service = ShareService();
        final profile = Profile(
          userId: 'user-001',
          email: 'mario.rossi@galileimoro.edu.it',
          fullName: 'Mario Rossi',
          username: 'mario.rossi',
          classYear: '4A',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        expect(
          () => service.shareProfile(profile),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareText - error propagation
    // =========================================================================

    group('shareText', () {
      test('throws when Share plugin is not available', () {
        // Share.share throws MissingPluginException in test environment
        expect(
          () => ShareService.shareText('Hello Nova!'),
          throwsA(isA<Exception>()),
        );
      });

      test('throws with subject parameter', () {
        expect(
          () => ShareService.shareText('Hello!', subject: 'Test'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareWithFiles - error propagation
    // =========================================================================

    group('shareWithFiles', () {
      test('throws when Share plugin is not available', () {
        expect(
          () => ShareService.shareWithFiles('Text', ['/path/to/file.png']),
          throwsA(isA<Exception>()),
        );
      });

      test('throws with subject and multiple files', () {
        expect(
          () => ShareService.shareWithFiles(
            'Check this out',
            ['/file1.png', '/file2.jpg'],
            subject: 'Files',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // copyProfileLink - error propagation
    // =========================================================================

    group('copyProfileLink', () {
      test('throws when SupabaseConfig is not configured', () {
        final service = ShareService();
        final profile = Profile(
          userId: 'user-001',
          email: 'mario.rossi@galileimoro.edu.it',
          fullName: 'Mario Rossi',
          username: 'mario.rossi',
          classYear: '4A',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        expect(
          () => service.copyProfileLink(profile),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // shareProfileInChat - uses username when fullName is empty
    // =========================================================================

    group('shareProfileInChat edge cases', () {
      test('throws for profile with empty fullName (falls back to username)',
          () {
        final service = ShareService();
        final profile = Profile(
          userId: 'user-002',
          email: 'test@galileimoro.edu.it',
          fullName: '',
          username: 'test.user',
          classYear: '3B',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

        // Still throws because SupabaseConfig is not configured,
        // but exercises the empty fullName branch
        expect(
          () => service.shareProfileInChat(
            profile,
            onNavigateToChat: (_) {},
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // ShareException - additional edge cases
    // =========================================================================

    group('ShareException additional', () {
      test('handles unicode in message', () {
        final exception = ShareException('Errore: condivisione fallita 🚫');

        expect(exception.message, contains('fallita'));
        expect(exception.toString(), startsWith('ShareException:'));
      });

      test('handles very long message', () {
        final longMessage = 'x' * 1000;
        final exception = ShareException(longMessage);

        expect(exception.message.length, equals(1000));
      });
    });
  });
}
