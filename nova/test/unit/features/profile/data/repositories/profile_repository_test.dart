import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:nova/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';
import 'package:nova/features/profile/data/repositories/profile_repository.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import 'package:nova/features/profile/domain/entities/profile_stats.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

class MockProfileLocalDataSource extends Mock
    implements ProfileLocalDataSource {}

class MockConnectivity extends Mock implements Connectivity {}

// ============================================================================
// HELPERS
// ============================================================================

ProfileModel _testProfileModel({
  String userId = 'user-001',
  String fullName = 'Mario Rossi',
  String? classYear = '4A',
  bool profileVisible = true,
}) {
  return ProfileModel(
    userId: userId,
    email: 'mario.rossi@galileimoro.edu.it',
    fullName: fullName,
    username: 'mario.rossi',
    classYear: classYear,
    avatarUrl: 'https://example.com/avatar.jpg',
    bio: 'Ciao!',
    role: 'student',
    profileVisible: profileVisible,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );
}

void main() {
  late ProfileRepository repository;
  late MockProfileRemoteDataSource mockRemote;
  late MockProfileLocalDataSource mockLocal;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockRemote = MockProfileRemoteDataSource();
    mockLocal = MockProfileLocalDataSource();
    mockConnectivity = MockConnectivity();
    repository = ProfileRepository(mockRemote, mockLocal, mockConnectivity);
  });

  setUpAll(() {
    registerFallbackValue(_testProfileModel());
  });

  // ==========================================================================
  // getProfile - Happy paths
  // ==========================================================================

  group('getProfile', () {
    test('returns remote profile and caches locally when online', () async {
      final model = _testProfileModel();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.getProfile('user-001'))
          .thenAnswer((_) async => model);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});

      final result = await repository.getProfile('user-001');

      expect(result.userId, 'user-001');
      expect(result.fullName, 'Mario Rossi');
      verify(() => mockLocal.saveProfile(model)).called(1);
    });

    test('returns cached profile when offline', () async {
      final model = _testProfileModel();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(() => mockLocal.getProfile('user-001')).thenReturn(model);

      final result = await repository.getProfile('user-001');

      expect(result.userId, 'user-001');
      verifyNever(() => mockRemote.getProfile(any()));
    });

    test('falls back to local cache on remote error', () async {
      final model = _testProfileModel();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.getProfile('user-001'))
          .thenThrow(Exception('Network error'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(model);

      final result = await repository.getProfile('user-001');

      expect(result.userId, 'user-001');
    });

    // Edge: no cache available offline
    test('throws ProfileCacheNotFoundException when offline with no cache',
        () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(() => mockLocal.getProfile('user-001')).thenReturn(null);

      expect(
        () => repository.getProfile('user-001'),
        throwsA(isA<ProfileCacheNotFoundException>()),
      );
    });

    // Edge: ProfileNotFoundException clears cache and rethrows
    test('clears stale cache on ProfileNotFoundException', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.getProfile('user-001'))
          .thenThrow(ProfileNotFoundException('not found'));
      when(() => mockLocal.deleteProfile('user-001'))
          .thenAnswer((_) async {});

      expect(
        () => repository.getProfile('user-001'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    // Edge: remote fails + no local cache rethrows
    test('rethrows when remote fails and no local cache', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.getProfile('user-001'))
          .thenThrow(Exception('Server down'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(null);

      expect(
        () => repository.getProfile('user-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // createProfile - Happy + Edge
  // ==========================================================================

  group('createProfile', () {
    test('creates remotely and caches when online', () async {
      final profile = _testProfileModel().toEntity();
      final createdModel = _testProfileModel();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.createProfile(any()))
          .thenAnswer((_) async => createdModel);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});

      final result = await repository.createProfile(profile);

      expect(result.userId, 'user-001');
      verify(() => mockRemote.createProfile(any())).called(1);
      verify(() => mockLocal.saveProfile(createdModel)).called(1);
    });

    // Edge: offline queues for sync
    test('throws OfflineModeException and queues when offline', () async {
      final profile = _testProfileModel().toEntity();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockLocal.saveToPendingSync(any()))
          .thenAnswer((_) async {});

      expect(
        () => repository.createProfile(profile),
        throwsA(isA<OfflineModeException>()),
      );
    });

    // Edge: remote error saves locally for retry
    test('saves locally on remote error for later retry', () async {
      final profile = _testProfileModel().toEntity();
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.createProfile(any()))
          .thenThrow(Exception('Server error'));
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockLocal.saveToPendingSync(any()))
          .thenAnswer((_) async {});

      expect(
        () => repository.createProfile(profile),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // updateProfile - Race conditions
  // ==========================================================================

  group('updateProfile', () {
    test('optimistic update: saves locally then syncs remote', () async {
      final currentModel = _testProfileModel();
      final updatedModel = _testProfileModel(fullName: 'Mario Updated');
      when(() => mockLocal.getProfile('user-001')).thenReturn(currentModel);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.updateProfile('user-001', any()))
          .thenAnswer((_) async => updatedModel);
      when(() => mockLocal.removeFromPendingSync('user-001'))
          .thenAnswer((_) async {});

      final result = await repository.updateProfile(
        'user-001',
        {'full_name': 'Mario Updated'},
      );

      expect(result.fullName, 'Mario Updated');
      // saveProfile called twice: optimistic + server response
      verify(() => mockLocal.saveProfile(any())).called(2);
    });

    // Race: concurrent update - remote fails, queued for retry
    test('queues pending sync when remote update fails', () async {
      final currentModel = _testProfileModel();
      when(() => mockLocal.getProfile('user-001')).thenReturn(currentModel);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.updateProfile('user-001', any()))
          .thenThrow(Exception('Conflict'));
      when(() => mockLocal.saveToPendingSync(any()))
          .thenAnswer((_) async {});

      expect(
        () => repository.updateProfile('user-001', {'bio': 'new bio'}),
        throwsA(isA<Exception>()),
      );
    });

    // Race: update with no cached profile
    test('throws when no cached profile to update', () async {
      when(() => mockLocal.getProfile('user-001')).thenReturn(null);

      expect(
        () => repository.updateProfile('user-001', {'bio': 'new'}),
        throwsA(isA<ProfileCacheNotFoundException>()),
      );
    });
  });

  // ==========================================================================
  // deleteProfile
  // ==========================================================================

  group('deleteProfile', () {
    test('deletes remotely and clears local cache', () async {
      when(() => mockRemote.deleteProfile('user-001'))
          .thenAnswer((_) async {});
      when(() => mockLocal.deleteProfile('user-001'))
          .thenAnswer((_) async {});
      when(() => mockLocal.removeFromPendingSync('user-001'))
          .thenAnswer((_) async {});

      await repository.deleteProfile('user-001');

      verify(() => mockRemote.deleteProfile('user-001')).called(1);
      verify(() => mockLocal.deleteProfile('user-001')).called(1);
      verify(() => mockLocal.removeFromPendingSync('user-001')).called(1);
    });
  });

  // ==========================================================================
  // getPublicProfile
  // ==========================================================================

  group('getPublicProfile', () {
    test('returns profile when visible', () async {
      final model = _testProfileModel(profileVisible: true);
      when(() => mockRemote.getProfileById('user-001'))
          .thenAnswer((_) async => model);

      final result = await repository.getPublicProfile('user-001');

      expect(result, isNotNull);
      expect(result!.userId, 'user-001');
    });

    test('returns null when profile is not visible', () async {
      final model = _testProfileModel(profileVisible: false);
      when(() => mockRemote.getProfileById('user-001'))
          .thenAnswer((_) async => model);

      final result = await repository.getPublicProfile('user-001');

      expect(result, isNull);
    });

    test('returns null on error', () async {
      when(() => mockRemote.getProfileById('user-001'))
          .thenThrow(Exception('not found'));

      final result = await repository.getPublicProfile('user-001');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // getProfileStats
  // ==========================================================================

  group('getProfileStats', () {
    test('returns stats from remote', () async {
      final stats = ProfileStats(eventsCreatedCount: 5, participationsCount: 3);
      when(() => mockRemote.getProfileStats('user-001'))
          .thenAnswer((_) async => stats);

      final result = await repository.getProfileStats('user-001');

      expect(result.eventsCreatedCount, 5);
      expect(result.participationsCount, 3);
    });

    test('returns empty stats on error', () async {
      when(() => mockRemote.getProfileStats('user-001'))
          .thenThrow(Exception('error'));

      final result = await repository.getProfileStats('user-001');

      expect(result, ProfileStats.empty());
    });
  });

  // ==========================================================================
  // isProfileComplete
  // ==========================================================================

  group('isProfileComplete', () {
    test('returns true from remote when complete', () async {
      when(() => mockRemote.isProfileComplete('user-001'))
          .thenAnswer((_) async => true);

      final result = await repository.isProfileComplete('user-001');

      expect(result, true);
    });

    test('falls back to local cache on remote error', () async {
      final model = _testProfileModel(classYear: '4A');
      when(() => mockRemote.isProfileComplete('user-001'))
          .thenThrow(Exception('offline'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(model);

      final result = await repository.isProfileComplete('user-001');

      expect(result, true);
    });

    test('returns false when no cache and remote fails', () async {
      when(() => mockRemote.isProfileComplete('user-001'))
          .thenThrow(Exception('offline'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(null);

      final result = await repository.isProfileComplete('user-001');

      expect(result, false);
    });

    test('returns false when local cache has empty classYear', () async {
      final model = _testProfileModel(classYear: '');
      when(() => mockRemote.isProfileComplete('user-001'))
          .thenThrow(Exception('offline'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(model);

      final result = await repository.isProfileComplete('user-001');

      expect(result, false);
    });

    test('returns false when local cache has null classYear', () async {
      final model = _testProfileModel(classYear: null);
      when(() => mockRemote.isProfileComplete('user-001'))
          .thenThrow(Exception('offline'));
      when(() => mockLocal.getProfile('user-001')).thenReturn(model);

      final result = await repository.isProfileComplete('user-001');

      expect(result, false);
    });
  });

  // ==========================================================================
  // getProfileById
  // ==========================================================================

  group('getProfileById', () {
    test('returns profile from remote datasource', () async {
      final model = _testProfileModel();
      when(() => mockRemote.getProfileById('user-001'))
          .thenAnswer((_) async => model);

      final result = await repository.getProfileById('user-001');

      expect(result.userId, 'user-001');
      expect(result.fullName, 'Mario Rossi');
      // Does NOT cache locally
      verifyNever(() => mockLocal.saveProfile(any()));
    });

    test('throws when remote fails (no local fallback)', () async {
      when(() => mockRemote.getProfileById('user-001'))
          .thenThrow(Exception('Not found'));

      expect(
        () => repository.getProfileById('user-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // syncPendingChanges
  // ==========================================================================

  group('syncPendingChanges', () {
    test('does nothing when no pending profiles', () async {
      when(() => mockLocal.getPendingSync()).thenReturn({});

      await repository.syncPendingChanges();

      verifyNever(() => mockConnectivity.checkConnectivity());
    });

    test('does nothing when still offline', () async {
      final model = _testProfileModel();
      when(() => mockLocal.getPendingSync()).thenReturn({'user-001': model});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);

      await repository.syncPendingChanges();

      verifyNever(() => mockRemote.updateProfile(any(), any()));
      verifyNever(() => mockRemote.createProfile(any()));
    });

    test('updates existing profiles when online', () async {
      final model = _testProfileModel();
      when(() => mockLocal.getPendingSync()).thenReturn({'user-001': model});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockLocal.hasProfile('user-001')).thenReturn(true);
      when(() => mockRemote.updateProfile('user-001', any()))
          .thenAnswer((_) async => model);
      when(() => mockLocal.removeFromPendingSync('user-001'))
          .thenAnswer((_) async {});

      await repository.syncPendingChanges();

      verify(() => mockRemote.updateProfile('user-001', any())).called(1);
      verify(() => mockLocal.removeFromPendingSync('user-001')).called(1);
    });

    test('creates new profiles when local profile does not exist', () async {
      final model = _testProfileModel();
      when(() => mockLocal.getPendingSync()).thenReturn({'user-001': model});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockLocal.hasProfile('user-001')).thenReturn(false);
      when(() => mockRemote.createProfile(any()))
          .thenAnswer((_) async => model);
      when(() => mockLocal.removeFromPendingSync('user-001'))
          .thenAnswer((_) async {});

      await repository.syncPendingChanges();

      verify(() => mockRemote.createProfile(any())).called(1);
      verify(() => mockLocal.removeFromPendingSync('user-001')).called(1);
    });

    test('keeps entry in queue on sync error and continues', () async {
      final model1 = _testProfileModel(userId: 'user-001');
      final model2 = _testProfileModel(userId: 'user-002');
      when(() => mockLocal.getPendingSync()).thenReturn({
        'user-001': model1,
        'user-002': model2,
      });
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockLocal.hasProfile('user-001')).thenReturn(true);
      when(() => mockLocal.hasProfile('user-002')).thenReturn(true);
      // First fails, second succeeds
      when(() => mockRemote.updateProfile('user-001', any()))
          .thenThrow(Exception('Server error'));
      when(() => mockRemote.updateProfile('user-002', any()))
          .thenAnswer((_) async => model2);
      when(() => mockLocal.removeFromPendingSync('user-002'))
          .thenAnswer((_) async {});

      await repository.syncPendingChanges();

      // user-001 was NOT removed from pending sync
      verifyNever(() => mockLocal.removeFromPendingSync('user-001'));
      // user-002 WAS removed
      verify(() => mockLocal.removeFromPendingSync('user-002')).called(1);
    });
  });

  // ==========================================================================
  // parseNameFromEmail & isUsernameAvailable
  // ==========================================================================

  group('parseNameFromEmail', () {
    test('delegates to remote datasource', () async {
      when(() => mockRemote.parseNameFromEmail('mario.rossi@school.it'))
          .thenAnswer((_) async => 'Mario Rossi');

      final result = await repository.parseNameFromEmail('mario.rossi@school.it');

      expect(result, 'Mario Rossi');
    });
  });

  group('isUsernameAvailable', () {
    test('delegates to remote datasource', () async {
      when(() => mockRemote.isUsernameAvailable('mario.rossi'))
          .thenAnswer((_) async => true);

      final result = await repository.isUsernameAvailable('mario.rossi');

      expect(result, true);
    });
  });

  group('isUsernameAvailableForUpdate', () {
    test('delegates to remote datasource with userId', () async {
      when(() => mockRemote.isUsernameAvailableForUpdate('mario.rossi', 'user-001'))
          .thenAnswer((_) async => true);

      final result = await repository.isUsernameAvailableForUpdate(
        'mario.rossi',
        'user-001',
      );

      expect(result, true);
    });
  });

  // ==========================================================================
  // updateProfile - offline path
  // ==========================================================================

  group('updateProfile - offline', () {
    test('queues for sync and throws OfflineModeException when offline', () async {
      final currentModel = _testProfileModel();
      when(() => mockLocal.getProfile('user-001')).thenReturn(currentModel);
      when(() => mockLocal.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(() => mockLocal.saveToPendingSync(any())).thenAnswer((_) async {});

      expect(
        () => repository.updateProfile('user-001', {'bio': 'new bio'}),
        throwsA(isA<OfflineModeException>()),
      );
    });
  });
}
