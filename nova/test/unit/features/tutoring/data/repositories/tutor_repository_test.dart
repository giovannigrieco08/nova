import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/tutoring/data/datasources/tutor_remote_datasource.dart';
import 'package:nova/features/tutoring/data/models/tutor_profile_model.dart';
import 'package:nova/features/tutoring/data/repositories/tutor_repository.dart';
import 'package:nova/features/tutoring/domain/entities/subject.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockTutorRemoteDataSource extends Mock implements TutorRemoteDataSource {}

// ============================================================================
// HELPERS
// ============================================================================

TutorProfileModel _testModel({
  String userId = 'user-001',
  bool isActive = true,
}) {
  return TutorProfileModel(
    id: 'tutor-001',
    userId: userId,
    bio: 'Ripetizioni di matematica',
    subjects: ['matematica', 'fisica'],
    pricePerHour: 15.0,
    availabilityDays: ['monday', 'wednesday'],
    timeSlot: '15:00-18:00',
    whatsappPhone: '+393331234567',
    instagramUsername: 'mario.tutor',
    rating: 4.5,
    totalReviews: 10,
    isActive: isActive,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );
}

TutorProfileWithAuthor _testModelWithAuthor({
  String userId = 'user-001',
}) {
  return TutorProfileWithAuthor(
    id: 'tutor-001',
    userId: userId,
    bio: 'Ripetizioni',
    subjects: ['matematica'],
    pricePerHour: 15.0,
    availabilityDays: ['monday'],
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    authorName: 'Mario Rossi',
    authorAvatarUrl: 'https://example.com/avatar.jpg',
    authorClass: '4A',
    authorUsername: 'mario.rossi',
  );
}

void main() {
  late TutorRepository repository;
  late MockTutorRemoteDataSource mockRemote;

  setUp(() {
    mockRemote = MockTutorRemoteDataSource();
    repository = TutorRepository(mockRemote);
  });

  // ==========================================================================
  // getTutorProfile - Happy paths
  // ==========================================================================

  group('getTutorProfile', () {
    test('returns TutorProfile entity when found', () async {
      when(() => mockRemote.getTutorProfile('user-001'))
          .thenAnswer((_) async => _testModel());

      final result = await repository.getTutorProfile('user-001');

      expect(result, isNotNull);
      expect(result!.userId, 'user-001');
      expect(result.subjects, contains(Subject.matematica));
      expect(result.pricePerHour, 15.0);
    });

    test('returns null when user is not a tutor', () async {
      when(() => mockRemote.getTutorProfile('user-002'))
          .thenAnswer((_) async => null);

      final result = await repository.getTutorProfile('user-002');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // getTutorsBySubject
  // ==========================================================================

  group('getTutorsBySubject', () {
    test('returns list of TutorProfileWithAuthorData', () async {
      when(() => mockRemote.getTutorsBySubject('matematica',
              offset: 0, limit: 20))
          .thenAnswer((_) async => [_testModelWithAuthor()]);

      final result =
          await repository.getTutorsBySubject(Subject.matematica);

      expect(result.length, 1);
      expect(result.first.authorName, 'Mario Rossi');
      expect(result.first.profile.subjects, contains(Subject.matematica));
    });

    // Edge: empty results
    test('returns empty list when no tutors found', () async {
      when(() =>
              mockRemote.getTutorsBySubject('greco', offset: 0, limit: 20))
          .thenAnswer((_) async => []);

      final result = await repository.getTutorsBySubject(Subject.greco);

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // createTutorProfile - Happy + Edge
  // ==========================================================================

  group('createTutorProfile', () {
    test('creates profile and returns entity', () async {
      when(() => mockRemote.createTutorProfile(
            userId: 'user-001',
            bio: 'Bio text',
            subjects: ['matematica'],
            pricePerHour: 10.0,
            availabilityDays: ['monday'],
            timeSlot: '15:00-17:00',
            whatsappPhone: '+393331234567',
            instagramUsername: null,
          )).thenAnswer((_) async => _testModel());

      final result = await repository.createTutorProfile(
        userId: 'user-001',
        bio: 'Bio text',
        subjects: [Subject.matematica],
        pricePerHour: 10.0,
        availabilityDays: [AvailabilityDay.monday],
        timeSlot: '15:00-17:00',
        whatsappPhone: '+393331234567',
      );

      expect(result.userId, 'user-001');
    });

    // Edge: TutorAlreadyExistsException propagates
    test('rethrows TutorAlreadyExistsException', () async {
      when(() => mockRemote.createTutorProfile(
            userId: any(named: 'userId'),
            bio: any(named: 'bio'),
            subjects: any(named: 'subjects'),
            pricePerHour: any(named: 'pricePerHour'),
            availabilityDays: any(named: 'availabilityDays'),
            timeSlot: any(named: 'timeSlot'),
            whatsappPhone: any(named: 'whatsappPhone'),
            instagramUsername: any(named: 'instagramUsername'),
          )).thenThrow(TutorAlreadyExistsException('Hai gia un profilo tutor'));

      expect(
        () => repository.createTutorProfile(
          userId: 'user-001',
          subjects: [Subject.matematica],
        ),
        throwsA(isA<TutorAlreadyExistsException>()),
      );
    });
  });

  // ==========================================================================
  // toggleTutorActive - Happy
  // ==========================================================================

  group('toggleTutorActive', () {
    test('deactivates when isActive is false', () async {
      when(() => mockRemote.deactivateTutorProfile('user-001'))
          .thenAnswer((_) async => _testModel(isActive: false));

      final result = await repository.toggleTutorActive('user-001', false);

      expect(result.isActive, false);
      verify(() => mockRemote.deactivateTutorProfile('user-001')).called(1);
    });

    test('reactivates when isActive is true', () async {
      when(() => mockRemote.reactivateTutorProfile('user-001'))
          .thenAnswer((_) async => _testModel(isActive: true));

      final result = await repository.toggleTutorActive('user-001', true);

      expect(result.isActive, true);
      verify(() => mockRemote.reactivateTutorProfile('user-001')).called(1);
    });
  });

  // ==========================================================================
  // deleteTutorProfile
  // ==========================================================================

  group('deleteTutorProfile', () {
    test('delegates to remote', () async {
      when(() => mockRemote.deleteTutorProfile('user-001'))
          .thenAnswer((_) async {});

      await repository.deleteTutorProfile('user-001');

      verify(() => mockRemote.deleteTutorProfile('user-001')).called(1);
    });

    // Edge: TutorDeletionException propagates
    test('rethrows TutorDeletionException', () async {
      when(() => mockRemote.deleteTutorProfile('user-001'))
          .thenThrow(TutorDeletionException('Cannot delete'));

      expect(
        () => repository.deleteTutorProfile('user-001'),
        throwsA(isA<TutorDeletionException>()),
      );
    });
  });
}
