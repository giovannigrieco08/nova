import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:nova/features/chat/data/models/chat_message_model.dart';
import 'package:nova/features/chat/data/models/chat_reaction_model.dart';
import 'package:nova/features/chat/data/models/chat_report_model.dart';
import 'package:nova/features/chat/data/models/chat_media_model.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:storage_client/storage_client.dart' show FileObject;

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  late ChatRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    dataSource = ChatRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper: message JSON
  // ==========================================================================

  Map<String, dynamic> _messageJson({
    String id = 'msg-001',
    String userId = 'test-student-001',
    String content = 'Ciao!',
  }) {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'mentions': <dynamic>[],
      'reaction_count': 0,
      'reply_count': 0,
      'report_count': 0,
      'created_at': DateTime.now().toIso8601String(),
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
    };
  }

  // ==========================================================================
  // getMessages
  // ==========================================================================

  group('getMessages', () {
    test('happy: returns list of ChatMessageModel', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([_messageJson(), _messageJson(id: 'msg-002')]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMessages();

      expect(result.length, 2);
      expect(result.first, isA<ChatMessageModel>());
    });

    test('happy: applies beforeTimestamp filter', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([_messageJson()]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMessages(
        beforeTimestamp: DateTime.now(),
        limit: 10,
      );

      expect(result.length, 1);
    });

    test('happy: returns empty list when no messages', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMessages();

      expect(result, isEmpty);
    });

    test('edge: throws on database error', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      // Override limit to throw so the await triggers the catch block
      when(() => fb.limit(any())).thenThrow(Exception('DB tables missing'));
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.getMessages(),
        throwsA(isA<Exception>()),
      );
    });

    test('happy: respects custom limit parameter', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([_messageJson()]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      await dataSource.getMessages(limit: 5);

      verify(() => fb.limit(5)).called(1);
    });
  });

  // ==========================================================================
  // getMessage
  // ==========================================================================

  group('getMessage', () {
    test('happy: returns ChatMessageModel when found', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([_messageJson()]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMessage('msg-001');

      expect(result, isNotNull);
      expect(result!.id, 'msg-001');
    });

    test('edge: returns null when message not found', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      // mockListQuery with empty list already sets maybeSingle to return null
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMessage('nonexistent');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // sendMessage
  // ==========================================================================

  group('sendMessage', () {
    test('edge: propagates P0001 for rate limit', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(<String, dynamic>{});
      // Override single() to throw synchronously.
      // The datasource does: await ...insert().select().single()
      // Throwing from single() means the error happens before await,
      // which is then caught by the enclosing async function.
      when(() => fb.single()).thenThrow(PostgrestException(
        message: 'Rate limit',
        code: 'P0001',
      ));
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.sendMessage(
          userId: TestUserIds.student1,
          content: 'spam',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('edge: propagates P0002 for profanity', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(<String, dynamic>{});
      when(() => fb.single()).thenThrow(PostgrestException(
        message: 'Profanity detected',
        code: 'P0002',
      ));
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.sendMessage(
          userId: TestUserIds.student1,
          content: 'bad',
        ),
        throwsA(isA<PostgrestException>().having(
          (e) => e.code,
          'code',
          'P0002',
        )),
      );
    });
  });

  // ==========================================================================
  // deleteMessage
  // ==========================================================================

  group('deleteMessage', () {
    test('happy: soft deletes media files and message', () async {
      // Mock media query (chat_media): select('storage_path').eq(...)
      final mockMediaQb = MockSupabaseQueryBuilder();
      final mediaFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockMediaQb);
      when(() => mockMediaQb.select(any())).thenAnswer((_) => mediaFb);

      // Mock soft delete (chat_messages): update({...}).eq(...)
      final mockMsgQb = MockSupabaseQueryBuilder();
      final updateFb = mockVoidQuery();
      when(() => mockSupabase.from('chat_messages'))
          .thenAnswer((_) => mockMsgQb);
      when(() => mockMsgQb.update(any())).thenAnswer((_) => updateFb);

      await dataSource.deleteMessage('msg-001');

      // Verify chat_messages update was called
      verify(() => mockSupabase.from('chat_messages')).called(1);
    });

    test('edge: ignores errors when deleting media files', () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();

      // Mock media query with a file
      final mockMediaQb = MockSupabaseQueryBuilder();
      final mediaFb = mockListQuery([
        {'storage_path': 'user/file.jpg'}
      ]);
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockMediaQb);
      when(() => mockMediaQb.select(any())).thenAnswer((_) => mediaFb);

      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from(any())).thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.remove(any()))
          .thenThrow(Exception('Storage error'));

      // Mock soft delete (chat_messages) - should still succeed
      final mockMsgQb = MockSupabaseQueryBuilder();
      final updateFb = mockVoidQuery();
      when(() => mockSupabase.from('chat_messages'))
          .thenAnswer((_) => mockMsgQb);
      when(() => mockMsgQb.update(any())).thenAnswer((_) => updateFb);

      await dataSource.deleteMessage('msg-001');
    });
  });

  // ==========================================================================
  // Reactions
  // ==========================================================================

  group('addReaction', () {
    test('happy: upserts reaction', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.upsert(any(), onConflict: any(named: 'onConflict')))
          .thenAnswer((_) => fb);

      await dataSource.addReaction(
        messageId: 'msg-001',
        userId: 'user-1',
        emoji: '👍',
      );

      verify(() => mockQb.upsert(any(), onConflict: any(named: 'onConflict')))
          .called(1);
    });

    test('race: concurrent reactions from same user', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.upsert(any(), onConflict: any(named: 'onConflict')))
          .thenAnswer((_) => fb);

      await Future.wait([
        dataSource.addReaction(
          messageId: 'msg-001',
          userId: 'user-1',
          emoji: '👍',
        ),
        dataSource.addReaction(
          messageId: 'msg-001',
          userId: 'user-1',
          emoji: '❤️',
        ),
      ]);

      verify(() => mockQb.upsert(any(), onConflict: any(named: 'onConflict')))
          .called(2);
    });
  });

  group('removeReaction', () {
    test('happy: deletes reaction', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await dataSource.removeReaction(
        messageId: 'msg-001',
        userId: 'user-1',
        emoji: '👍',
      );
    });
  });

  // ==========================================================================
  // Reports
  // ==========================================================================

  group('submitReport', () {
    test('edge: returns null for duplicate report (23505)', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(<String, dynamic>{});
      when(() => fb.single()).thenThrow(PostgrestException(
        message: 'Duplicate',
        code: '23505',
      ));
      when(() => mockSupabase.from('chat_reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.submitReport(
        messageId: 'msg-001',
        reporterUserId: 'user-1',
        reason: ChatReportReason.spam,
      );

      expect(result, isNull);
    });

    test('edge: rethrows non-23505 errors', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(<String, dynamic>{});
      when(() => fb.single()).thenThrow(PostgrestException(
        message: 'Server error',
        code: '42000',
      ));
      when(() => mockSupabase.from('chat_reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.submitReport(
          messageId: 'msg-001',
          reporterUserId: 'user-1',
          reason: ChatReportReason.spam,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // hasUserReported
  // ==========================================================================

  group('hasUserReported', () {
    test('happy: returns true when report exists', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([{'id': 'report-1'}]);
      when(() => mockSupabase.from('chat_reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.hasUserReported(
        messageId: 'msg-001',
        userId: 'user-1',
      );

      expect(result, isTrue);
    });

    test('happy: returns false when no report', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      // mockListQuery with empty list sets maybeSingle to return null
      when(() => mockSupabase.from('chat_reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.hasUserReported(
        messageId: 'msg-001',
        userId: 'user-1',
      );

      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // searchUsersForMention
  // ==========================================================================

  group('searchUsersForMention', () {
    test('happy: returns parsed MentionSearchResults', () async {
      final rpcFb = mockListQuery([
        {
          'user_id': 'user-1',
          'full_name': 'Mario Rossi',
          'avatar_url': null,
          'class': '4A',
        },
      ]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final results = await dataSource.searchUsersForMention('mar');

      expect(results.length, 1);
      expect(results.first.fullName, 'Mario Rossi');
    });

    test('race: concurrent mention searches', () async {
      final rpcFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      await Future.wait([
        dataSource.searchUsersForMention('mar'),
        dataSource.searchUsersForMention('luc'),
      ]);

      verify(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .called(2);
    });
  });

  // ==========================================================================
  // Pin Messages
  // ==========================================================================

  group('pinMessage', () {
    test('happy: unpins existing and pins new message', () async {
      // pinMessage calls from('chat_messages') twice:
      // 1) update({is_pinned: false, ...}).eq('is_pinned', true)  -> void
      // 2) update({is_pinned: true, ...}).eq('id', messageId).select(...).single() -> message
      //
      // Since both use from('chat_messages'), we use a single query builder.
      // mockSingleQuery handles both the void-await path and the select/single path.
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(_messageJson());
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.pinMessage(
        messageId: 'msg-001',
        pinnedByUserId: 'user-1',
      );

      // Verifies at least one call to chat_messages
      verify(() => mockSupabase.from('chat_messages')).called(greaterThan(0));
    });
  });

  // ==========================================================================
  // unpinMessage
  // ==========================================================================

  group('unpinMessage', () {
    test('happy: updates message to unpin', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.unpinMessage('msg-001');

      verify(() => mockQb.update(any())).called(1);
    });
  });

  // ==========================================================================
  // getPinnedMessage
  // ==========================================================================

  group('getPinnedMessage', () {
    test('happy: returns pinned message when exists', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([_messageJson()]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getPinnedMessage();

      expect(result, isNotNull);
      expect(result, isA<ChatMessageModel>());
    });

    test('edge: returns null when no pinned message', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getPinnedMessage();

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // editMessage
  // ==========================================================================

  group('editMessage', () {
    test('happy: updates content and returns updated model', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(_messageJson(content: 'Edited content'));
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.editMessage(
        messageId: 'msg-001',
        newContent: 'Edited content',
      );

      expect(result, isA<ChatMessageModel>());
      expect(result.content, 'Edited content');
    });
  });

  // ==========================================================================
  // sendGifMessage
  // ==========================================================================

  group('sendGifMessage', () {
    test('happy: sends gif message and returns model', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final gifMsgJson = _messageJson(content: '[GIF]');
      gifMsgJson['gif_url'] = 'https://example.com/funny.gif';
      gifMsgJson['gif_id'] = 'gif-123';
      final fb = mockSingleQuery(gifMsgJson);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.sendGifMessage(
        userId: TestUserIds.student1,
        gifUrl: 'https://example.com/funny.gif',
        gifId: 'gif-123',
      );

      expect(result, isA<ChatMessageModel>());
    });
  });

  // ==========================================================================
  // sendMessage - happy path
  // ==========================================================================

  group('sendMessage - happy', () {
    test('happy: sends message and returns model', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery(_messageJson(content: 'Hello'));
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.sendMessage(
        userId: TestUserIds.student1,
        content: 'Hello',
      );

      expect(result, isA<ChatMessageModel>());
      expect(result.content, 'Hello');
    });

    test('happy: sends message with reply and mentions', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final msgJson = _messageJson(content: '@mario ciao');
      msgJson['reply_to_id'] = 'msg-000';
      msgJson['mentions'] = [
        {'user_id': 'user-1', 'full_name': 'Mario'}
      ];
      final fb = mockSingleQuery(msgJson);
      when(() => mockSupabase.from('chat_messages')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.sendMessage(
        userId: TestUserIds.student1,
        content: '@mario ciao',
        replyToId: 'msg-000',
        mentions: [
          {'user_id': 'user-1', 'full_name': 'Mario'}
        ],
      );

      expect(result, isA<ChatMessageModel>());
    });
  });

  // ==========================================================================
  // getReactionsForMessage
  // ==========================================================================

  group('getReactionsForMessage', () {
    test('happy: returns list of reaction models', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'message_id': 'msg-001',
          'user_id': 'user-1',
          'emoji': '👍',
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getReactionsForMessage('msg-001');

      expect(result.length, 1);
      expect(result.first, isA<ChatReactionModel>());
      expect(result.first.emoji, '👍');
    });

    test('happy: returns empty list when no reactions', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getReactionsForMessage('msg-001');

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // reportScreenshot
  // ==========================================================================

  group('reportScreenshot', () {
    test('happy: updates screenshot_detected_at', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.reportScreenshot('media-001');

      verify(() => mockQb.update(any())).called(1);
    });
  });

  // ==========================================================================
  // getTodayMediaCount
  // ==========================================================================

  group('getTodayMediaCount', () {
    test('happy: returns count of today uploads', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {'id': 'media-1'},
        {'id': 'media-2'},
      ]);
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTodayMediaCount('user-1');

      expect(result, 2);
    });

    test('happy: returns 0 when no uploads today', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTodayMediaCount('user-1');

      expect(result, 0);
    });
  });

  // ==========================================================================
  // getReactionsWithUsers
  // ==========================================================================

  group('getReactionsWithUsers', () {
    test('happy: returns list of ReactionWithUser', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'emoji': '👍',
          'user_id': 'user-1',
          'created_at': DateTime.now().toIso8601String(),
          'profiles': {
            'full_name': 'Mario Rossi',
            'avatar_url': 'https://example.com/avatar.jpg',
          },
        },
        {
          'emoji': '❤️',
          'user_id': 'user-2',
          'created_at': DateTime.now().toIso8601String(),
          'profiles': {
            'full_name': 'Lucia Bianchi',
            'avatar_url': null,
          },
        },
      ]);
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getReactionsWithUsers('msg-001');

      expect(result.length, 2);
      expect(result.first, isA<ReactionWithUser>());
      expect(result.first.emoji, '👍');
      expect(result.first.fullName, 'Mario Rossi');
      expect(result.first.avatarUrl, 'https://example.com/avatar.jpg');
      expect(result[1].fullName, 'Lucia Bianchi');
      expect(result[1].avatarUrl, isNull);
    });

    test('happy: returns empty list when no reactions', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getReactionsWithUsers('msg-001');

      expect(result, isEmpty);
    });

    test('edge: defaults fullName to Utente when profiles is null', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'emoji': '👍',
          'user_id': 'user-1',
          'created_at': DateTime.now().toIso8601String(),
          'profiles': null,
        },
      ]);
      when(() => mockSupabase.from('chat_reactions'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getReactionsWithUsers('msg-001');

      expect(result.first.fullName, 'Utente');
    });
  });

  // ==========================================================================
  // markMediaViewed
  // ==========================================================================

  group('markMediaViewed', () {
    test('happy: returns updated ChatMediaModel from RPC (list response)',
        () async {
      final mediaJson = {
        'id': 'media-001',
        'message_id': 'msg-001',
        'uploader_user_id': 'user-1',
        'storage_path': 'user-1/file.webp',
        'media_type': 'image',
        'file_size_bytes': 12345,
        'max_views': 2,
        'view_count': 1,
        'duration_seconds': null,
        'screenshot_detected_at': null,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'viewed_at': null,
        'viewed_by_user_id': null,
        'screenshot_notified': false,
      };
      final rpcFb = mockFilterChain<dynamic>([mediaJson]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.markMediaViewed(
        mediaId: 'media-001',
        viewerUserId: 'user-2',
      );

      expect(result, isA<ChatMediaModel>());
    });

    test('edge: returns null when RPC returns null', () async {
      final rpcFb = mockFilterChain<dynamic>(null);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.markMediaViewed(
        mediaId: 'media-001',
        viewerUserId: 'user-2',
      );

      expect(result, isNull);
    });

    test('edge: returns null when RPC returns empty list', () async {
      final rpcFb = mockFilterChain<dynamic>(<dynamic>[]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.markMediaViewed(
        mediaId: 'media-001',
        viewerUserId: 'user-2',
      );

      expect(result, isNull);
    });

    test('happy: returns ChatMediaModel from RPC (map response)', () async {
      final mediaJson = {
        'id': 'media-001',
        'message_id': 'msg-001',
        'uploader_user_id': 'user-1',
        'storage_path': 'user-1/file.webp',
        'media_type': 'image',
        'file_size_bytes': 12345,
        'max_views': 1,
        'view_count': 1,
        'duration_seconds': null,
        'screenshot_detected_at': null,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'viewed_at': null,
        'viewed_by_user_id': null,
        'screenshot_notified': false,
      };
      final rpcFb = mockFilterChain<dynamic>(mediaJson);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.markMediaViewed(
        mediaId: 'media-001',
        viewerUserId: 'user-2',
      );

      expect(result, isA<ChatMediaModel>());
    });
  });

  // ==========================================================================
  // submitReport - happy path
  // ==========================================================================

  group('submitReport - happy', () {
    test('happy: creates report and returns ChatReportModel', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'id': 'report-001',
        'message_id': 'msg-001',
        'reporter_user_id': 'user-1',
        'reason': 'spam',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      when(() => mockSupabase.from('chat_reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.submitReport(
        messageId: 'msg-001',
        reporterUserId: 'user-1',
        reason: ChatReportReason.spam,
      );

      expect(result, isA<ChatReportModel>());
      expect(result!.messageId, 'msg-001');
    });
  });

  // ==========================================================================
  // getSignedMediaUrl
  // ==========================================================================

  group('getSignedMediaUrl', () {
    test('edge: returns null on storage error', () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();
      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from(any())).thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.createSignedUrl(any(), any()))
          .thenThrow(Exception('Storage error'));

      final result = await dataSource.getSignedMediaUrl('user/file.jpg');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // deleteMessage - with media files
  // ==========================================================================

  group('deleteMessage - with media', () {
    test('happy: deletes media from storage then soft deletes message',
        () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();

      // Mock media query returning files
      final mockMediaQb = MockSupabaseQueryBuilder();
      final mediaFb = mockListQuery([
        {'storage_path': 'user/file1.jpg'},
        {'storage_path': 'user/file2.jpg'},
      ]);
      when(() => mockSupabase.from('chat_media')).thenAnswer((_) => mockMediaQb);
      when(() => mockMediaQb.select(any())).thenAnswer((_) => mediaFb);

      // Mock storage operations
      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from(any())).thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.remove(any()))
          .thenAnswer((_) async => <FileObject>[]);

      // Mock soft delete
      final mockMsgQb = MockSupabaseQueryBuilder();
      final updateFb = mockVoidQuery();
      when(() => mockSupabase.from('chat_messages'))
          .thenAnswer((_) => mockMsgQb);
      when(() => mockMsgQb.update(any())).thenAnswer((_) => updateFb);

      await dataSource.deleteMessage('msg-001');

      verify(() => mockStorageFile.remove(any())).called(2);
    });
  });
}
