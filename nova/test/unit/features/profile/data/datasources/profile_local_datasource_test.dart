import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockProfileBox extends Mock implements Box<ProfileModel> {}

// ============================================================================
// HELPERS
// ============================================================================

ProfileModel _testModel({String userId = 'user-001'}) {
  return ProfileModel(
    userId: userId,
    email: 'mario@galileimoro.edu.it',
    fullName: 'Mario Rossi',
    username: 'mario.rossi',
    classYear: '4A',
    role: 'student',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  late ProfileLocalDataSource dataSource;
  late MockProfileBox mockBox;

  setUpAll(() {
    registerFallbackValue(_testModel());
    registerFallbackValue('');
  });

  setUp(() {
    mockBox = MockProfileBox();
    dataSource = ProfileLocalDataSource(mockBox);
  });

  // ==========================================================================
  // saveProfile + getProfile - Happy paths
  // ==========================================================================

  group('saveProfile and getProfile', () {
    test('saves profile with correct key', () async {
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      final model = _testModel();
      await dataSource.saveProfile(model);

      verify(() => mockBox.put('profile_user-001', model)).called(1);
    });

    test('retrieves profile by userId', () {
      final model = _testModel();
      when(() => mockBox.get('profile_user-001')).thenReturn(model);

      final result = dataSource.getProfile('user-001');

      expect(result, model);
      expect(result!.userId, 'user-001');
    });

    test('returns null when profile not found', () {
      when(() => mockBox.get('profile_missing')).thenReturn(null);

      final result = dataSource.getProfile('missing');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // Pending sync - Happy + Edge
  // ==========================================================================

  group('pending sync operations', () {
    test('saveToPendingSync stores with pending_sync_ prefix', () async {
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      final model = _testModel();
      await dataSource.saveToPendingSync(model);

      verify(() => mockBox.put('pending_sync_user-001', model)).called(1);
    });

    test('getPendingSync returns map of userId to ProfileModel', () {
      final model1 = _testModel(userId: 'user-001');
      final model2 = _testModel(userId: 'user-002');

      when(() => mockBox.keys).thenReturn([
        'profile_user-001',
        'pending_sync_user-001',
        'pending_sync_user-002',
      ]);
      when(() => mockBox.get('pending_sync_user-001')).thenReturn(model1);
      when(() => mockBox.get('pending_sync_user-002')).thenReturn(model2);

      final result = dataSource.getPendingSync();

      expect(result.length, 2);
      expect(result['user-001'], model1);
      expect(result['user-002'], model2);
    });

    // Edge: empty pending sync
    test('getPendingSync returns empty map when no pending items', () {
      when(() => mockBox.keys).thenReturn(['profile_user-001']);

      final result = dataSource.getPendingSync();

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // hasProfile + deleteProfile
  // ==========================================================================

  group('hasProfile', () {
    test('returns true when profile exists', () {
      when(() => mockBox.containsKey('profile_user-001')).thenReturn(true);

      expect(dataSource.hasProfile('user-001'), true);
    });

    test('returns false when profile does not exist', () {
      when(() => mockBox.containsKey('profile_user-999')).thenReturn(false);

      expect(dataSource.hasProfile('user-999'), false);
    });
  });

  group('deleteProfile', () {
    test('deletes profile by key', () async {
      when(() => mockBox.delete(any())).thenAnswer((_) async {});

      await dataSource.deleteProfile('user-001');

      verify(() => mockBox.delete('profile_user-001')).called(1);
    });
  });
}
