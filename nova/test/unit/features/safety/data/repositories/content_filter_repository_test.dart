import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/safety/data/models/content_check_result.dart';
import 'package:nova/features/safety/data/repositories/content_filter_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late ContentFilterRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenAnswer((_) => mockAuth);
    when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);
    when(() => mockUser.id).thenReturn('user-001');

    repository = ContentFilterRepository(supabase: mockSupabase);
  });

  group('checkContent', () {
    test('returns clean result for safe text', () async {
      when(() => mockSupabase.rpc('check_content', params: {'p_text': 'Hello'}))
          .thenAnswer((_) => mockFilterChain<dynamic>({
                'allowed': true,
                'blocked': false,
                'matched_words': <String>[],
                'severity': null,
              }));

      final result = await repository.checkContent('Hello');

      expect(result.allowed, true);
      expect(result.blocked, false);
      expect(result.matchedWords, isEmpty);
    });

    test('returns blocked result for banned words', () async {
      when(() => mockSupabase.rpc('check_content',
              params: {'p_text': 'bad word'}))
          .thenAnswer((_) => mockFilterChain<dynamic>({
                'allowed': false,
                'blocked': true,
                'matched_words': ['bad'],
                'severity': 'block',
              }));

      final result = await repository.checkContent('bad word');

      expect(result.blocked, true);
      expect(result.matchedWords, ['bad']);
      expect(result.severity, ContentSeverity.block);
    });

    test('returns clean result for empty text without RPC call', () async {
      final result = await repository.checkContent('');

      expect(result.isClean, true);
      verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
    });

    test('returns clean result when RPC returns null', () async {
      when(() =>
              mockSupabase.rpc('check_content', params: {'p_text': 'test'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(null));

      final result = await repository.checkContent('test');

      expect(result.isClean, true);
    });
  });

  group('getBannedWords', () {
    test('returns list of banned words', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'id': 'word-001',
          'word': 'badword',
          'pattern_type': 'exact',
          'severity': 'block',
          'language': 'it',
          'created_by': 'admin-001',
          'created_at': '2025-01-01T00:00:00.000',
          'deleted_at': null,
        }
      ]);
      when(() => mockSupabase.from('banned_words')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getBannedWords();

      expect(result.length, 1);
      expect(result.first.word, 'badword');
      expect(result.first.isActive, true);
    });

    test('filters by language when specified', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('banned_words')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getBannedWords(language: 'en');

      expect(result, isEmpty);
    });
  });

  group('addBannedWord', () {
    test('inserts and returns BannedWord', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'id': 'word-001',
        'word': 'newbad',
        'pattern_type': 'exact',
        'severity': 'block',
        'language': 'it',
        'created_by': 'user-001',
        'created_at': '2025-06-01T00:00:00.000',
        'deleted_at': null,
      });
      when(() => mockSupabase.from('banned_words')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await repository.addBannedWord(
        word: 'newbad',
        patternType: 'exact',
        severity: 'block',
      );

      expect(result.word, 'newbad');
    });

    test('throws when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      expect(
        () => repository.addBannedWord(
          word: 'bad',
          patternType: 'exact',
          severity: 'block',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('removeBannedWord', () {
    test('soft deletes by setting deleted_at', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('banned_words')).thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await repository.removeBannedWord('word-001');

      verify(() => mockQb.update(any())).called(1);
    });
  });
}
