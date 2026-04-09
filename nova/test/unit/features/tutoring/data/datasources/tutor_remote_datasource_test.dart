import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/tutoring/data/datasources/tutor_remote_datasource.dart';
import 'package:nova/features/tutoring/data/models/tutor_profile_model.dart';
import '../../../../../mocks/mock_supabase.dart';

// ============================================================================
// HELPERS
// ============================================================================

Map<String, dynamic> _tutorProfileJson({
  String id = 'tutor-001',
  String userId = 'user-001',
  String? bio = 'Esperto di matematica',
  List<String> subjects = const ['matematica', 'fisica'],
  double pricePerHour = 15.0,
  List<String> availabilityDays = const ['lunedi', 'mercoledi'],
  String? timeSlot = 'pomeriggio',
  String? whatsappPhone = '+39 333 1234567',
  String? instagramUsername = 'mario_tutor',
  double rating = 4.5,
  int totalReviews = 10,
  bool isActive = true,
  String createdAt = '2025-06-01T10:00:00.000',
  String updatedAt = '2025-06-02T10:00:00.000',
}) =>
    {
      'id': id,
      'user_id': userId,
      'bio': bio,
      'subjects': subjects,
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
      'rating': rating,
      'total_reviews': totalReviews,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };

Map<String, dynamic> _tutorProfileWithAuthorJson({
  String id = 'tutor-001',
  String userId = 'user-001',
}) =>
    {
      ..._tutorProfileJson(id: id, userId: userId),
      'profiles': {
        'full_name': 'Mario Rossi',
        'avatar_url': 'https://example.com/avatar.jpg',
        'class': '4A',
        'username': 'mario.rossi',
      },
    };

/// Creates a filter builder that throws [error] when awaited via .maybeSingle().
MockPostgrestTransformBuilder<Map<String, dynamic>?>
    _throwingMaybeSingleBuilder(Object error) {
  final tb = MockPostgrestTransformBuilder<Map<String, dynamic>?>();
  final errorFuture = Future<Map<String, dynamic>?>.error(error);
  errorFuture.catchError((_) => null);

  when(() => tb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0]
        as dynamic Function(Map<String, dynamic>?);
    final onError = invocation.namedArguments[#onError] as Function?;
    return errorFuture.then<dynamic>(onValue, onError: onError);
  });
  return tb;
}

/// Creates a filter builder that throws [error] when awaited via .single().
MockPostgrestTransformBuilder<Map<String, dynamic>>
    _throwingSingleBuilder(Object error) {
  final tb = MockPostgrestTransformBuilder<Map<String, dynamic>>();
  final errorFuture = Future<Map<String, dynamic>>.error(error);
  errorFuture.catchError((_) => <String, dynamic>{});

  when(() => tb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0]
        as dynamic Function(Map<String, dynamic>);
    final onError = invocation.namedArguments[#onError] as Function?;
    return errorFuture.then<dynamic>(onValue, onError: onError);
  });
  return tb;
}

/// Creates a list filter builder that throws [error] when awaited.
MockPostgrestFilterBuilder<List<Map<String, dynamic>>>
    _throwingListFilterBuilder(Object error) {
  final fb = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
  ensureMockFallbacks();

  when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.contains(any(), any())).thenAnswer((_) => fb);
  when(() => fb.order(any(), ascending: any(named: 'ascending')))
      .thenAnswer((_) => fb);
  when(() => fb.range(any(), any())).thenAnswer((_) => fb);
  when(() => fb.select(any())).thenAnswer((_) => fb);
  when(() => fb.select()).thenAnswer((_) => fb);
  when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
  when(() => fb.lte(any(), any())).thenAnswer((_) => fb);

  final errorFuture = Future<List<Map<String, dynamic>>>.error(error);
  errorFuture.catchError((_) => <Map<String, dynamic>>[]);

  when(() => fb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    final onError = invocation.namedArguments[#onError] as Function?;
    return errorFuture.then<dynamic>(
      (v) => onValue(v),
      onError: onError,
    );
  });
  return fb;
}

void main() {
  late TutorRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQb;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQb = MockSupabaseQueryBuilder();
    dataSource = TutorRemoteDataSource(mockSupabase);
  });

  setUpAll(() {
    ensureMockFallbacks();
  });

  // ==========================================================================
  // getTutorProfile
  // ==========================================================================

  group('getTutorProfile', () {
    test('returns TutorProfileModel when profile exists', () async {
      final json = _tutorProfileJson();
      final fb = mockListQuery([json]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getTutorProfile('user-001');

      expect(result, isNotNull);
      expect(result!.id, 'tutor-001');
      expect(result.userId, 'user-001');
      expect(result.bio, 'Esperto di matematica');
      expect(result.subjects, ['matematica', 'fisica']);
      expect(result.pricePerHour, 15.0);
      expect(result.isActive, true);
    });

    test('returns null when profile does not exist', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getTutorProfile('nonexistent-user');

      expect(result, isNull);
    });

    test('returns null on PGRST116 error', () async {
      final fb = mockListQuery([_tutorProfileJson()]);
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      // Override .maybeSingle() to throw PGRST116
      final throwingTb = _throwingMaybeSingleBuilder(
        PostgrestException(code: 'PGRST116', message: 'No rows'),
      );
      when(() => fb.maybeSingle()).thenAnswer((_) => throwingTb);

      final result = await dataSource.getTutorProfile('user-001');
      expect(result, isNull);
    });

    test('rethrows non-PGRST116 PostgrestException', () async {
      final fb = mockListQuery([_tutorProfileJson()]);
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final throwingTb = _throwingMaybeSingleBuilder(
        PostgrestException(code: '42P01', message: 'Table not found'),
      );
      when(() => fb.maybeSingle()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.getTutorProfile('user-001'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // getTutorsBySubject
  // ==========================================================================

  group('getTutorsBySubject', () {
    test('returns list of TutorProfileWithAuthor', () async {
      final data = [
        _tutorProfileWithAuthorJson(id: 'tutor-001', userId: 'user-001'),
        _tutorProfileWithAuthorJson(id: 'tutor-002', userId: 'user-002'),
      ];
      final fb = mockListQuery(data);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTutorsBySubject('matematica');

      expect(result, hasLength(2));
      expect(result[0], isA<TutorProfileWithAuthor>());
      expect(result[0].authorName, 'Mario Rossi');
      expect(result[0].authorClass, '4A');
    });

    test('returns empty list when no tutors for subject', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTutorsBySubject('latino');

      expect(result, isEmpty);
    });

    test('throws TutorQueryException on PostgrestException', () async {
      final fb = _throwingListFilterBuilder(
        PostgrestException(code: '42P01', message: 'relation does not exist'),
      );

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.getTutorsBySubject('matematica'),
        throwsA(isA<TutorQueryException>()),
      );
    });

    test('uses offset and limit parameters', () async {
      final fb = mockListQuery([_tutorProfileWithAuthorJson()]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTutorsBySubject(
        'matematica',
        offset: 10,
        limit: 5,
      );

      expect(result, hasLength(1));
      verify(() => fb.range(10, 14)).called(1);
    });
  });

  // ==========================================================================
  // getTutorsFiltered
  // ==========================================================================

  group('getTutorsFiltered', () {
    test('returns tutors without price filter', () async {
      final data = [_tutorProfileWithAuthorJson()];
      final fb = mockListQuery(data);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getTutorsFiltered('matematica');

      expect(result, hasLength(1));
    });

    test('applies free price filter', () async {
      final fb = mockListQuery([_tutorProfileWithAuthorJson()]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      await dataSource.getTutorsFiltered('matematica', priceFilter: 'free');

      // free filter calls eq('price_per_hour', 0) in addition to
      // eq('is_active', true) — verify price filter was applied
      verify(() => fb.eq('price_per_hour', 0)).called(1);
    });

    test('applies 1-15 price range filter', () async {
      final fb = mockListQuery([_tutorProfileWithAuthorJson()]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      await dataSource.getTutorsFiltered('matematica', priceFilter: '1-15');

      verify(() => fb.gte('price_per_hour', 1)).called(1);
      verify(() => fb.lte('price_per_hour', 15)).called(1);
    });

    test('applies 16-30 price range filter', () async {
      final fb = mockListQuery([_tutorProfileWithAuthorJson()]);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      await dataSource.getTutorsFiltered('matematica', priceFilter: '16-30');

      verify(() => fb.gte('price_per_hour', 16)).called(1);
      verify(() => fb.lte('price_per_hour', 30)).called(1);
    });

    test('throws TutorQueryException on error', () async {
      final fb = _throwingListFilterBuilder(
        PostgrestException(code: '42P01', message: 'error'),
      );

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.getTutorsFiltered('matematica'),
        throwsA(isA<TutorQueryException>()),
      );
    });
  });

  // ==========================================================================
  // isTutor
  // ==========================================================================

  group('isTutor', () {
    test('returns true when profile exists', () async {
      final fb = mockListQuery([_tutorProfileJson()]);
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.isTutor('user-001');
      expect(result, isTrue);
    });

    test('returns false when profile does not exist', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.isTutor('nonexistent-user');
      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // createTutorProfile
  // ==========================================================================

  group('createTutorProfile', () {
    test('creates and returns new tutor profile', () async {
      final json = _tutorProfileJson();
      final fb = mockSingleQuery(json);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.createTutorProfile(
        userId: 'user-001',
        bio: 'Esperto di matematica',
        subjects: ['matematica', 'fisica'],
        pricePerHour: 15.0,
        availabilityDays: ['lunedi', 'mercoledi'],
        timeSlot: 'pomeriggio',
        whatsappPhone: '+39 333 1234567',
        instagramUsername: 'mario_tutor',
      );

      expect(result.id, 'tutor-001');
      expect(result.userId, 'user-001');
      expect(result.subjects, ['matematica', 'fisica']);
    });

    test('throws TutorAlreadyExistsException on duplicate (23505)', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      // Override .single() to throw duplicate key error
      final throwingTb = _throwingSingleBuilder(
        PostgrestException(code: '23505', message: 'duplicate key'),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.createTutorProfile(
          userId: 'user-001',
          subjects: ['matematica'],
          whatsappPhone: '+39 333 1234567',
        ),
        throwsA(isA<TutorAlreadyExistsException>()),
      );
    });

    test('throws TutorValidationException on contact_required constraint', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(
          code: '23514',
          message: 'check constraint contact_required violated',
        ),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.createTutorProfile(
          userId: 'user-001',
          subjects: ['matematica'],
        ),
        throwsA(isA<TutorValidationException>()),
      );
    });

    test('throws TutorValidationException on bio constraint', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(
          code: '23514',
          message: 'check constraint bio length violated',
        ),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.createTutorProfile(
          userId: 'user-001',
          subjects: ['matematica'],
          bio: 'a' * 300,
          whatsappPhone: '+39 333 1234567',
        ),
        throwsA(isA<TutorValidationException>()),
      );
    });

    test('throws TutorValidationException on subjects constraint', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(
          code: '23514',
          message: 'check constraint subjects max violated',
        ),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.createTutorProfile(
          userId: 'user-001',
          subjects: ['a', 'b', 'c', 'd', 'e', 'f'],
          whatsappPhone: '+39 333 1234567',
        ),
        throwsA(isA<TutorValidationException>()),
      );
    });

    test('rethrows other PostgrestException', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(code: '42P01', message: 'table not found'),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.createTutorProfile(
          userId: 'user-001',
          subjects: ['matematica'],
          whatsappPhone: '+39 333 1234567',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // updateTutorProfile
  // ==========================================================================

  group('updateTutorProfile', () {
    test('updates and returns tutor profile', () async {
      final json = _tutorProfileJson(bio: 'Updated bio');
      final fb = mockSingleQuery(json);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.updateTutorProfile(
        'user-001',
        bio: 'Updated bio',
      );

      expect(result.bio, 'Updated bio');
    });

    test('only includes provided fields in update', () async {
      final json = _tutorProfileJson(pricePerHour: 20.0);
      final fb = mockSingleQuery(json);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.updateTutorProfile(
        'user-001',
        pricePerHour: 20.0,
      );

      final captured = verify(() => mockQb.update(captureAny())).captured;
      final updateMap = captured.first as Map<String, dynamic>;
      expect(updateMap, {'price_per_hour': 20.0});
    });

    test('throws TutorNotFoundException on PGRST116', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(code: 'PGRST116', message: 'No rows'),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.updateTutorProfile('nonexistent', bio: 'test'),
        throwsA(isA<TutorNotFoundException>()),
      );
    });

    test('throws TutorValidationException on contact_required constraint', () async {
      final fb = mockSingleQuery(_tutorProfileJson());
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final throwingTb = _throwingSingleBuilder(
        PostgrestException(
          code: '23514',
          message: 'check constraint contact_required violated',
        ),
      );
      when(() => fb.single()).thenAnswer((_) => throwingTb);

      expect(
        () => dataSource.updateTutorProfile(
          'user-001',
          whatsappPhone: '',
          instagramUsername: '',
        ),
        throwsA(isA<TutorValidationException>()),
      );
    });
  });

  // ==========================================================================
  // deactivateTutorProfile / reactivateTutorProfile
  // ==========================================================================

  group('deactivateTutorProfile', () {
    test('sets isActive to false', () async {
      final json = _tutorProfileJson(isActive: false);
      final fb = mockSingleQuery(json);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.deactivateTutorProfile('user-001');

      expect(result.isActive, false);
      final captured = verify(() => mockQb.update(captureAny())).captured;
      final updateMap = captured.first as Map<String, dynamic>;
      expect(updateMap, {'is_active': false});
    });
  });

  group('reactivateTutorProfile', () {
    test('sets isActive to true', () async {
      final json = _tutorProfileJson(isActive: true);
      final fb = mockSingleQuery(json);

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.reactivateTutorProfile('user-001');

      expect(result.isActive, true);
      final captured = verify(() => mockQb.update(captureAny())).captured;
      final updateMap = captured.first as Map<String, dynamic>;
      expect(updateMap, {'is_active': true});
    });
  });

  // ==========================================================================
  // deleteTutorProfile
  // ==========================================================================

  group('deleteTutorProfile', () {
    test('deletes tutor profile successfully', () async {
      final fb = mockVoidQuery();

      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await dataSource.deleteTutorProfile('user-001');

      verify(() => mockQb.delete()).called(1);
      verify(() => fb.eq('user_id', 'user-001')).called(1);
    });

    test('throws TutorDeletionException on error', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('tutor_profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      // Override await fb to throw
      when(() => fb.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) {
        final onError = invocation.namedArguments[#onError] as Function?;
        final errorFuture = Future<dynamic>.error(
          PostgrestException(code: '42501', message: 'permission denied'),
        );
        if (onError != null) {
          return errorFuture.then<dynamic>((_) => null, onError: onError);
        }
        return errorFuture;
      });

      expect(
        () => dataSource.deleteTutorProfile('user-001'),
        throwsA(isA<TutorDeletionException>()),
      );
    });
  });
}
