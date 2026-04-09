import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/profile/data/services/avatar_upload_service.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late AvatarUploadService service;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseStorageClient mockStorage;
  late MockStorageFileApi mockStorageFileApi;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    mockStorageFileApi = MockStorageFileApi();
    when(() => mockSupabase.storage).thenReturn(mockStorage);
    when(() => mockStorage.from('avatars')).thenReturn(mockStorageFileApi);
    service = AvatarUploadService(mockSupabase);
  });

  // ==========================================================================
  // normalizeAvatarUrl - Happy paths
  // ==========================================================================

  group('normalizeAvatarUrl', () {
    test('returns same URL if already public (no token)', () {
      const url =
          'https://xyz.supabase.co/storage/v1/object/public/avatars/user/file.png';

      final result = service.normalizeAvatarUrl(url);

      expect(result, url);
    });

    test('converts signed URL to public URL', () {
      const signedUrl =
          'https://xyz.supabase.co/storage/v1/object/sign/avatars/user/file.png?token=abc123';

      final result = service.normalizeAvatarUrl(signedUrl);

      expect(result, contains('/public/'));
      expect(result, isNot(contains('token=')));
    });

    test('returns empty string for null input', () {
      expect(service.normalizeAvatarUrl(null), '');
    });

    // Edge: empty string
    test('returns empty string for empty input', () {
      expect(service.normalizeAvatarUrl(''), '');
    });

    // Edge: malformed URL still returned
    test('returns original on non-parseable URL with token', () {
      // URLs that have 'token=' but no 'sign' segment
      const url = 'https://example.com/something?token=abc';
      final result = service.normalizeAvatarUrl(url);
      // Should return original since no 'sign' segment found
      expect(result, url);
    });
  });

  // ==========================================================================
  // deleteAvatar
  // ==========================================================================

  group('deleteAvatar', () {
    test('lists and removes files in user folder', () async {
      when(() => mockStorageFileApi.list(path: 'user-001'))
          .thenAnswer((_) async => [
                FileObject(
                  name: 'avatar.png',
                  id: 'id1',
                  owner: '',
                  createdAt: '2025-01-01',
                  updatedAt: '2025-01-01',
                  lastAccessedAt: '2025-01-01',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
              ]);
      when(() => mockStorageFileApi.remove(['user-001/avatar.png']))
          .thenAnswer((_) async => [
                FileObject(
                  name: 'avatar.png',
                  id: 'id1',
                  owner: '',
                  createdAt: '2025-01-01',
                  updatedAt: '2025-01-01',
                  lastAccessedAt: '2025-01-01',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
              ]);

      await service.deleteAvatar('user-001');

      verify(() => mockStorageFileApi.remove(['user-001/avatar.png'])).called(1);
    });

    // Edge: throws AvatarUploadException on storage error
    test('throws AvatarUploadException on storage error', () async {
      when(() => mockStorageFileApi.list(path: 'user-001'))
          .thenThrow(Exception('Storage down'));

      expect(
        () => service.deleteAvatar('user-001'),
        throwsA(isA<AvatarUploadException>()),
      );
    });
  });

  // ==========================================================================
  // getAvatarUrl
  // ==========================================================================

  group('getAvatarUrl', () {
    test('returns public URL for most recent avatar', () async {
      when(() => mockStorageFileApi.list(path: 'user-001'))
          .thenAnswer((_) async => [
                FileObject(
                  name: 'user-001_100.png',
                  id: 'id1',
                  owner: '',
                  createdAt: '2025-01-01',
                  updatedAt: '2025-01-01',
                  lastAccessedAt: '2025-01-01',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
                FileObject(
                  name: 'user-001_200.png',
                  id: 'id2',
                  owner: '',
                  createdAt: '2025-01-02',
                  updatedAt: '2025-01-02',
                  lastAccessedAt: '2025-01-02',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
              ]);
      when(() => mockStorageFileApi.getPublicUrl('user-001/user-001_200.png'))
          .thenReturn('https://cdn.example.com/avatars/user-001/user-001_200.png');

      final result = await service.getAvatarUrl('user-001');

      expect(result, contains('user-001_200.png'));
    });

    test('returns null when no avatar files exist', () async {
      when(() => mockStorageFileApi.list(path: 'user-001'))
          .thenAnswer((_) async => []);

      final result = await service.getAvatarUrl('user-001');

      expect(result, isNull);
    });

    // Edge: returns null on error
    test('returns null on storage error', () async {
      when(() => mockStorageFileApi.list(path: 'user-001'))
          .thenThrow(Exception('Storage error'));

      final result = await service.getAvatarUrl('user-001');

      expect(result, isNull);
    });

    test('picks alphabetically last file as most recent', () async {
      when(() => mockStorageFileApi.list(path: 'user-002'))
          .thenAnswer((_) async => [
                FileObject(
                  name: 'user-002_300.png',
                  id: 'id3',
                  owner: '',
                  createdAt: '2025-01-03',
                  updatedAt: '2025-01-03',
                  lastAccessedAt: '2025-01-03',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
                FileObject(
                  name: 'user-002_100.png',
                  id: 'id1',
                  owner: '',
                  createdAt: '2025-01-01',
                  updatedAt: '2025-01-01',
                  lastAccessedAt: '2025-01-01',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
              ]);
      when(() => mockStorageFileApi.getPublicUrl('user-002/user-002_300.png'))
          .thenReturn(
              'https://cdn.example.com/avatars/user-002/user-002_300.png');

      final result = await service.getAvatarUrl('user-002');

      expect(result, contains('user-002_300.png'));
    });
  });

  // ==========================================================================
  // normalizeAvatarUrl - additional edge cases
  // ==========================================================================

  group('normalizeAvatarUrl additional', () {
    test('preserves scheme and host when converting signed to public', () {
      const signedUrl =
          'https://xyz.supabase.co/storage/v1/object/sign/avatars/uid/file.png?token=abc123';

      final result = service.normalizeAvatarUrl(signedUrl);

      expect(result, startsWith('https://'));
      expect(result, contains('xyz.supabase.co'));
      expect(result, contains('/public/'));
      expect(result, contains('avatars/uid/file.png'));
    });

    test('handles URL with multiple query parameters', () {
      const signedUrl =
          'https://xyz.supabase.co/storage/v1/object/sign/avatars/uid/f.png?token=abc&extra=1';

      final result = service.normalizeAvatarUrl(signedUrl);

      expect(result, contains('/public/'));
      expect(result, isNot(contains('token=')));
      expect(result, isNot(contains('extra=')));
    });
  });

  // ==========================================================================
  // AvatarUploadException
  // ==========================================================================

  group('AvatarUploadException', () {
    test('stores message correctly', () {
      final exception = AvatarUploadException('upload failed');

      expect(exception.message, equals('upload failed'));
    });

    test('toString includes class prefix', () {
      final exception = AvatarUploadException('test error');

      expect(exception.toString(),
          equals('AvatarUploadException: test error'));
    });

    test('implements Exception interface', () {
      expect(AvatarUploadException('x'), isA<Exception>());
    });
  });

  // ==========================================================================
  // deleteAvatar - additional cases
  // ==========================================================================

  group('deleteAvatar additional', () {
    test('succeeds when user folder has no files', () async {
      when(() => mockStorageFileApi.list(path: 'user-empty'))
          .thenAnswer((_) async => []);

      // Should complete without error
      await service.deleteAvatar('user-empty');

      verify(() => mockStorageFileApi.list(path: 'user-empty')).called(1);
      verifyNever(
          () => mockStorageFileApi.remove(any()));
    });

    test('deletes multiple files in user folder', () async {
      when(() => mockStorageFileApi.list(path: 'user-multi'))
          .thenAnswer((_) async => [
                FileObject(
                  name: 'old.png',
                  id: 'id1',
                  owner: '',
                  createdAt: '2025-01-01',
                  updatedAt: '2025-01-01',
                  lastAccessedAt: '2025-01-01',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
                FileObject(
                  name: 'newer.png',
                  id: 'id2',
                  owner: '',
                  createdAt: '2025-01-02',
                  updatedAt: '2025-01-02',
                  lastAccessedAt: '2025-01-02',
                  bucketId: 'avatars',
                  metadata: {},
                  buckets: null,
                ),
              ]);
      when(() => mockStorageFileApi.remove(any()))
          .thenAnswer((_) async => []);

      await service.deleteAvatar('user-multi');

      verify(() => mockStorageFileApi.remove(['user-multi/old.png'])).called(1);
      verify(() => mockStorageFileApi.remove(['user-multi/newer.png']))
          .called(1);
    });
  });
}
