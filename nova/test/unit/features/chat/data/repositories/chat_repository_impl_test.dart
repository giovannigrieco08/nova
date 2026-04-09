import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

import 'package:nova/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:nova/features/chat/data/models/chat_message_model.dart';
import 'package:nova/features/chat/data/models/chat_reaction_model.dart';
import 'package:nova/features/chat/data/models/chat_report_model.dart';
import 'package:nova/features/chat/data/models/chat_media_model.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

class MockHiveBox extends Mock implements Box<Map<dynamic, dynamic>> {}

void main() {
  late ChatRepositoryImpl repository;
  late MockChatRemoteDataSource mockRemoteDataSource;
  late MockSupabaseClient mockSupabase;
  late MockHiveBox mockPendingBox;

  setUpAll(() {
    registerFallbackValue(ChatReportReason.spam);
  });

  setUp(() {
    mockRemoteDataSource = MockChatRemoteDataSource();
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    mockPendingBox = MockHiveBox();

    repository = ChatRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      supabase: mockSupabase,
      pendingMessagesBox: mockPendingBox,
    );
  });

  // ==========================================================================
  // Helper: create a ChatMessageModel
  // ==========================================================================

  ChatMessageModel _createMessageModel({
    String id = 'msg-001',
    String userId = 'test-student-001',
    String content = 'Ciao a tutti!',
    DateTime? createdAt,
  }) {
    return ChatMessageModel.fromJson({
      'id': id,
      'user_id': userId,
      'content': content,
      'mentions': <dynamic>[],
      'reaction_count': 0,
      'reply_count': 0,
      'report_count': 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': null,
      'deleted_by_user': false,
      'hidden_at': null,
      'hidden_reason': null,
      'reply_to_id': null,
      'gif_url': null,
      'gif_id': null,
      'edited_at': null,
      'is_pinned': false,
      'pinned_at': null,
      'pinned_by_user_id': null,
      'media_caption': null,
      'profiles': {
        'user_id': userId,
        'full_name': 'Mario Rossi',
        'username': 'mario.rossi',
        'avatar_url': null,
        'class': '4A',
        'profile_visible': true,
        'bio': null,
      },
      'chat_reactions': <dynamic>[],
      'chat_media': <dynamic>[],
    });
  }

  // ==========================================================================
  // sendMessage
  // ==========================================================================

  group('sendMessage', () {
    test('happy: sends message and returns ChatMessage entity', () async {
      final model = _createMessageModel();
      when(() => mockRemoteDataSource.sendMessage(
            userId: TestUserIds.student1,
            content: 'Hello',
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenAnswer((_) async => model);

      final result = await repository.sendMessage(content: 'Hello');

      expect(result, isA<ChatMessage>());
      expect(result.content, 'Ciao a tutti!');
    });

    test('happy: sends message with mentions and replyToId', () async {
      final model = _createMessageModel();
      final mentions = [
        {'user_id': 'user-2', 'username': 'lucia'}
      ];
      when(() => mockRemoteDataSource.sendMessage(
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenAnswer((_) async => model);

      final result = await repository.sendMessage(
        content: 'Hello @lucia',
        mentions: mentions,
        replyToId: 'msg-parent',
      );

      expect(result, isA<ChatMessage>());
    });

    test('edge: throws ChatRateLimitException on P0001', () async {
      when(() => mockRemoteDataSource.sendMessage(
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenThrow(PostgrestException(
        message: 'Rate limit exceeded',
        code: 'P0001',
      ));

      expect(
        () => repository.sendMessage(content: 'spam'),
        throwsA(isA<ChatRateLimitException>()),
      );
    });

    test('edge: throws ChatProfanityException on P0002', () async {
      when(() => mockRemoteDataSource.sendMessage(
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenThrow(PostgrestException(
        message: 'Profanity detected',
        code: 'P0002',
      ));

      expect(
        () => repository.sendMessage(content: 'bad word'),
        throwsA(isA<ChatProfanityException>()),
      );
    });

    test('edge: rethrows non-rate-limit PostgrestExceptions', () async {
      when(() => mockRemoteDataSource.sendMessage(
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenThrow(PostgrestException(
        message: 'Some other error',
        code: '42501',
      ));

      expect(
        () => repository.sendMessage(content: 'test'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // deleteMessage
  // ==========================================================================

  group('deleteMessage', () {
    test('happy: deletes own message', () async {
      final model = _createMessageModel(userId: TestUserIds.student1);
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async => model);
      when(() => mockRemoteDataSource.deleteMessage('msg-001'))
          .thenAnswer((_) async {});

      final result = await repository.deleteMessage('msg-001');

      expect(result, isTrue);
      verify(() => mockRemoteDataSource.deleteMessage('msg-001')).called(1);
    });

    test('edge: throws when message not found', () async {
      when(() => mockRemoteDataSource.getMessage('nonexistent'))
          .thenAnswer((_) async => null);

      expect(
        () => repository.deleteMessage('nonexistent'),
        throwsA(isA<ChatDeleteNotAllowedException>()),
      );
    });

    test('edge: throws when user is not the message owner', () async {
      final model = _createMessageModel(userId: 'other-user');
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async => model);

      expect(
        () => repository.deleteMessage('msg-001'),
        throwsA(isA<ChatDeleteNotAllowedException>()),
      );
    });

    test('race: concurrent delete calls for same message', () async {
      final model = _createMessageModel(userId: TestUserIds.student1);
      int callCount = 0;
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async {
        callCount++;
        if (callCount > 1) {
          // Second call sees deleted message
          return ChatMessageModel.fromJson({
            ..._createMessageModel().toJson(),
            'deleted_at': DateTime.now().toIso8601String(),
          });
        }
        return model;
      });
      when(() => mockRemoteDataSource.deleteMessage('msg-001'))
          .thenAnswer((_) async {});

      // First delete succeeds
      await repository.deleteMessage('msg-001');

      // Second delete should fail (already deleted)
      expect(
        () => repository.deleteMessage('msg-001'),
        throwsA(isA<ChatDeleteNotAllowedException>()),
      );
    });
  });

  // ==========================================================================
  // Reactions
  // ==========================================================================

  group('addReaction', () {
    test('happy: delegates to remote with currentUserId', () async {
      when(() => mockRemoteDataSource.addReaction(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
            emoji: '👍',
          )).thenAnswer((_) async {});

      await repository.addReaction(messageId: 'msg-001', emoji: '👍');

      verify(() => mockRemoteDataSource.addReaction(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
            emoji: '👍',
          )).called(1);
    });
  });

  group('getReactionsForMessage', () {
    test('happy: groups reactions by emoji', () async {
      final reactions = [
        ChatReactionModel.fromJson({
          'message_id': 'msg-001',
          'user_id': 'user-1',
          'emoji': '👍',
          'created_at': DateTime.now().toIso8601String(),
        }),
        ChatReactionModel.fromJson({
          'message_id': 'msg-001',
          'user_id': 'user-2',
          'emoji': '👍',
          'created_at': DateTime.now().toIso8601String(),
        }),
        ChatReactionModel.fromJson({
          'message_id': 'msg-001',
          'user_id': 'user-1',
          'emoji': '❤️',
          'created_at': DateTime.now().toIso8601String(),
        }),
      ];
      when(() => mockRemoteDataSource.getReactionsForMessage('msg-001'))
          .thenAnswer((_) async => reactions);

      final result = await repository.getReactionsForMessage('msg-001');

      expect(result['👍']!.length, 2);
      expect(result['❤️']!.length, 1);
    });
  });

  // ==========================================================================
  // Reports
  // ==========================================================================

  group('submitReport', () {
    test('happy: returns true on successful report', () async {
      when(() => mockRemoteDataSource.submitReport(
            messageId: 'msg-001',
            reporterUserId: TestUserIds.student1,
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => ChatReportModel.fromJson({
            'id': 'report-1',
            'message_id': 'msg-001',
            'reporter_user_id': TestUserIds.student1,
            'reason': 'spam',
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }));

      final result = await repository.submitReport(
        messageId: 'msg-001',
        reason: ChatReportReason.spam,
      );

      expect(result, isTrue);
    });

    test('edge: returns false when already reported (duplicate)', () async {
      when(() => mockRemoteDataSource.submitReport(
            messageId: 'msg-001',
            reporterUserId: TestUserIds.student1,
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => null);

      final result = await repository.submitReport(
        messageId: 'msg-001',
        reason: ChatReportReason.spam,
      );

      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // Mentions
  // ==========================================================================

  group('searchUsersForMention', () {
    test('happy: delegates to remote', () async {
      final results = [
        MentionSearchResult(
          userId: 'user-1',
          fullName: 'Mario Rossi',
          avatarUrl: null,
          studentClass: '4A',
        ),
      ];
      when(() => mockRemoteDataSource.searchUsersForMention('mar'))
          .thenAnswer((_) async => results);

      final actual = await repository.searchUsersForMention('mar');

      expect(actual.length, 1);
      expect(actual.first.fullName, 'Mario Rossi');
    });

    test('edge: returns empty for empty query', () async {
      final result = await repository.searchUsersForMention('');

      expect(result, isEmpty);
      verifyNever(() => mockRemoteDataSource.searchUsersForMention(any()));
    });
  });

  // ==========================================================================
  // GIF Messages
  // ==========================================================================

  group('sendGifMessage', () {
    test('happy: sends GIF message', () async {
      final model = _createMessageModel();
      when(() => mockRemoteDataSource.sendGifMessage(
            userId: any(named: 'userId'),
            gifUrl: any(named: 'gifUrl'),
            gifId: any(named: 'gifId'),
            replyToId: any(named: 'replyToId'),
          )).thenAnswer((_) async => model);

      final result = await repository.sendGifMessage(
        gifUrl: 'https://giphy.com/test.gif',
        gifId: 'abc123',
      );

      expect(result, isA<ChatMessage>());
    });

    test('edge: throws ChatRateLimitException on P0001', () async {
      when(() => mockRemoteDataSource.sendGifMessage(
            userId: any(named: 'userId'),
            gifUrl: any(named: 'gifUrl'),
            gifId: any(named: 'gifId'),
            replyToId: any(named: 'replyToId'),
          )).thenThrow(PostgrestException(
        message: 'Rate limit',
        code: 'P0001',
      ));

      expect(
        () => repository.sendGifMessage(
          gifUrl: 'url',
          gifId: 'id',
        ),
        throwsA(isA<ChatRateLimitException>()),
      );
    });
  });

  // ==========================================================================
  // Offline Support
  // ==========================================================================

  group('queueOfflineMessage', () {
    test('happy: stores pending message in Hive', () async {
      when(() => mockPendingBox.put(any(), any()))
          .thenAnswer((_) async {});

      await repository.queueOfflineMessage(content: 'Offline msg');

      verify(() => mockPendingBox.put(any(), any())).called(1);
    });

    test('race: concurrent offline queue and send', () async {
      when(() => mockPendingBox.put(any(), any()))
          .thenAnswer((_) async {});

      final model = _createMessageModel();
      when(() => mockRemoteDataSource.sendMessage(
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            mentions: any(named: 'mentions'),
            replyToId: any(named: 'replyToId'),
          )).thenAnswer((_) async => model);

      // Both operations should complete independently
      await Future.wait([
        repository.queueOfflineMessage(content: 'Queued msg'),
        repository.sendMessage(content: 'Live msg'),
      ]);

      verify(() => mockPendingBox.put(any(), any())).called(1);
    });

    test('race: multiple offline messages queued in parallel', () async {
      when(() => mockPendingBox.put(any(), any()))
          .thenAnswer((_) async {});

      await Future.wait([
        repository.queueOfflineMessage(content: 'Msg 1'),
        repository.queueOfflineMessage(content: 'Msg 2'),
        repository.queueOfflineMessage(content: 'Msg 3'),
      ]);

      verify(() => mockPendingBox.put(any(), any())).called(3);
    });
  });

  // ==========================================================================
  // Edit Messages
  // ==========================================================================

  group('editMessage', () {
    test('happy: edits own message within window', () async {
      final model = _createMessageModel(userId: TestUserIds.student1);
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async => model);
      when(() => mockRemoteDataSource.editMessage(
            messageId: 'msg-001',
            newContent: 'Updated content',
          )).thenAnswer((_) async => model);

      final result = await repository.editMessage(
        messageId: 'msg-001',
        newContent: 'Updated content',
      );

      expect(result, isA<ChatMessage>());
    });

    test('edge: throws when message not found', () async {
      when(() => mockRemoteDataSource.getMessage(any()))
          .thenAnswer((_) async => null);

      expect(
        () => repository.editMessage(
          messageId: 'nonexistent',
          newContent: 'new',
        ),
        throwsA(isA<ChatEditNotAllowedException>()),
      );
    });

    test('edge: throws when user is not message owner', () async {
      final model = _createMessageModel(userId: 'other-user');
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async => model);

      expect(
        () => repository.editMessage(
          messageId: 'msg-001',
          newContent: 'new',
        ),
        throwsA(isA<ChatEditNotAllowedException>()),
      );
    });
  });

  // ==========================================================================
  // Pin Messages
  // ==========================================================================

  group('pinMessage', () {
    test('happy: pins message', () async {
      final model = _createMessageModel();
      when(() => mockRemoteDataSource.pinMessage(
            messageId: 'msg-001',
            pinnedByUserId: TestUserIds.student1,
          )).thenAnswer((_) async => model);

      final result = await repository.pinMessage('msg-001');

      expect(result, isA<ChatMessage>());
    });
  });

  group('getPinnedMessage', () {
    test('happy: returns pinned message', () async {
      final model = _createMessageModel();
      when(() => mockRemoteDataSource.getPinnedMessage())
          .thenAnswer((_) async => model);

      final result = await repository.getPinnedMessage();

      expect(result, isNotNull);
    });

    test('edge: returns null when no pinned message', () async {
      when(() => mockRemoteDataSource.getPinnedMessage())
          .thenAnswer((_) async => null);

      final result = await repository.getPinnedMessage();

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // getMessage
  // ==========================================================================

  group('getMessage', () {
    test('happy: returns entity when message exists', () async {
      final model = _createMessageModel();
      when(() => mockRemoteDataSource.getMessage('msg-001'))
          .thenAnswer((_) async => model);

      final result = await repository.getMessage('msg-001');

      expect(result, isNotNull);
      expect(result, isA<ChatMessage>());
      expect(result!.content, 'Ciao a tutti!');
    });

    test('edge: returns null when message not found', () async {
      when(() => mockRemoteDataSource.getMessage('nonexistent'))
          .thenAnswer((_) async => null);

      final result = await repository.getMessage('nonexistent');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // loadMoreMessages
  // ==========================================================================

  group('loadMoreMessages', () {
    test('happy: returns list of entities with pagination', () async {
      final models = [
        _createMessageModel(id: 'msg-001'),
        _createMessageModel(id: 'msg-002'),
      ];
      final timestamp = DateTime(2025, 6, 1);
      when(() => mockRemoteDataSource.getMessages(
            limit: 20,
            beforeTimestamp: timestamp,
          )).thenAnswer((_) async => models);

      final result = await repository.loadMoreMessages(
        beforeTimestamp: timestamp,
        limit: 20,
      );

      expect(result.length, 2);
      expect(result.first, isA<ChatMessage>());
    });

    test('edge: returns empty list when no more messages', () async {
      final timestamp = DateTime(2025, 1, 1);
      when(() => mockRemoteDataSource.getMessages(
            limit: 20,
            beforeTimestamp: timestamp,
          )).thenAnswer((_) async => []);

      final result = await repository.loadMoreMessages(
        beforeTimestamp: timestamp,
        limit: 20,
      );

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // removeReaction
  // ==========================================================================

  group('removeReaction', () {
    test('happy: delegates to remote with currentUserId', () async {
      when(() => mockRemoteDataSource.removeReaction(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
            emoji: '👍',
          )).thenAnswer((_) async {});

      await repository.removeReaction(messageId: 'msg-001', emoji: '👍');

      verify(() => mockRemoteDataSource.removeReaction(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
            emoji: '👍',
          )).called(1);
    });
  });

  // ==========================================================================
  // hasUserReported
  // ==========================================================================

  group('hasUserReported', () {
    test('happy: returns true when user has reported', () async {
      when(() => mockRemoteDataSource.hasUserReported(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
          )).thenAnswer((_) async => true);

      final result = await repository.hasUserReported('msg-001');

      expect(result, isTrue);
    });

    test('happy: returns false when user has not reported', () async {
      when(() => mockRemoteDataSource.hasUserReported(
            messageId: 'msg-001',
            userId: TestUserIds.student1,
          )).thenAnswer((_) async => false);

      final result = await repository.hasUserReported('msg-001');

      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // watchReactionsForMessage
  // ==========================================================================

  group('watchReactionsForMessage', () {
    test('edge: throws UnimplementedError', () {
      expect(
        () => repository.watchReactionsForMessage('msg-001'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  // ==========================================================================
  // markMediaViewed
  // ==========================================================================

  group('markMediaViewed', () {
    test('happy: returns entity when media viewed successfully', () async {
      final model = ChatMediaModel(
        id: 'media-001',
        messageId: 'msg-001',
        uploaderUserId: 'other-user',
        storagePath: 'other-user/file.webp',
        mediaType: 'image',
        fileSizeBytes: 1024,
        maxViews: 1,
        viewCount: 1,
        screenshotNotified: false,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      );
      when(() => mockRemoteDataSource.markMediaViewed(
            mediaId: 'media-001',
            viewerUserId: TestUserIds.student1,
          )).thenAnswer((_) async => model);

      final result = await repository.markMediaViewed('media-001');

      expect(result, isNotNull);
      expect(result, isA<ChatMediaInfo>());
      expect(result!.id, 'media-001');
    });

    test('edge: returns null when max views exceeded', () async {
      when(() => mockRemoteDataSource.markMediaViewed(
            mediaId: 'media-001',
            viewerUserId: TestUserIds.student1,
          )).thenAnswer((_) async => null);

      final result = await repository.markMediaViewed('media-001');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // reportScreenshot
  // ==========================================================================

  group('reportScreenshot', () {
    test('happy: delegates to remote datasource', () async {
      when(() => mockRemoteDataSource.reportScreenshot('media-001'))
          .thenAnswer((_) async {});

      await repository.reportScreenshot('media-001');

      verify(() => mockRemoteDataSource.reportScreenshot('media-001')).called(1);
    });
  });

  // ==========================================================================
  // getTodayMediaCount
  // ==========================================================================

  group('getTodayMediaCount', () {
    test('happy: returns count from remote', () async {
      when(() => mockRemoteDataSource.getTodayMediaCount(TestUserIds.student1))
          .thenAnswer((_) async => 3);

      final result = await repository.getTodayMediaCount();

      expect(result, 3);
    });

    test('edge: returns zero when no media uploaded today', () async {
      when(() => mockRemoteDataSource.getTodayMediaCount(TestUserIds.student1))
          .thenAnswer((_) async => 0);

      final result = await repository.getTodayMediaCount();

      expect(result, 0);
    });
  });

  // ==========================================================================
  // getPendingMessages
  // ==========================================================================

  group('getPendingMessages', () {
    test('happy: returns pending messages from Hive box', () async {
      final now = DateTime.now();
      when(() => mockPendingBox.values).thenReturn([
        {
          'local_id': 'local-1',
          'content': 'Offline msg 1',
          'mentions': <dynamic>[],
          'reply_to_id': null,
          'queued_at': now.toIso8601String(),
          'retry_count': 0,
        },
        {
          'local_id': 'local-2',
          'content': 'Offline msg 2',
          'mentions': <dynamic>[],
          'reply_to_id': 'msg-parent',
          'queued_at': now.toIso8601String(),
          'retry_count': 2,
        },
      ]);

      final result = await repository.getPendingMessages();

      expect(result.length, 2);
      expect(result.first.localId, 'local-1');
      expect(result.first.content, 'Offline msg 1');
      expect(result.last.replyToId, 'msg-parent');
      expect(result.last.retryCount, 2);
    });

    test('edge: returns empty list when no pending messages', () async {
      when(() => mockPendingBox.values).thenReturn([]);

      final result = await repository.getPendingMessages();

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // clearPendingMessage
  // ==========================================================================

  group('clearPendingMessage', () {
    test('happy: deletes message from Hive box by localId', () async {
      when(() => mockPendingBox.delete('local-1'))
          .thenAnswer((_) async {});

      await repository.clearPendingMessage('local-1');

      verify(() => mockPendingBox.delete('local-1')).called(1);
    });
  });

  // ==========================================================================
  // unpinMessage
  // ==========================================================================

  group('unpinMessage', () {
    test('happy: delegates to remote datasource', () async {
      when(() => mockRemoteDataSource.unpinMessage('msg-001'))
          .thenAnswer((_) async {});

      await repository.unpinMessage('msg-001');

      verify(() => mockRemoteDataSource.unpinMessage('msg-001')).called(1);
    });
  });

  // ==========================================================================
  // getSignedMediaUrl
  // ==========================================================================

  group('getSignedMediaUrl', () {
    test('happy: returns signed URL when views available', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'storage_path': 'user/file.webp',
        'max_views': 2,
        'view_count': 1,
      });
      when(() => mockSupabase.from('chat_media'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select('storage_path, max_views, view_count'))
          .thenAnswer((_) => fb);

      when(() => mockRemoteDataSource.getSignedMediaUrl('user/file.webp'))
          .thenAnswer((_) async => 'https://signed-url.com/file.webp');

      final result = await repository.getSignedMediaUrl('media-001');

      expect(result, 'https://signed-url.com/file.webp');
    });

    test('edge: returns null when media record not found', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_media'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select('storage_path, max_views, view_count'))
          .thenAnswer((_) => fb);

      final result = await repository.getSignedMediaUrl('nonexistent');

      expect(result, isNull);
    });

    test('edge: returns null when max views exceeded', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'storage_path': 'user/file.webp',
        'max_views': 1,
        'view_count': 1,
      });
      when(() => mockSupabase.from('chat_media'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select('storage_path, max_views, view_count'))
          .thenAnswer((_) => fb);

      final result = await repository.getSignedMediaUrl('media-001');

      expect(result, isNull);
      verifyNever(() => mockRemoteDataSource.getSignedMediaUrl(any()));
    });
  });
}
