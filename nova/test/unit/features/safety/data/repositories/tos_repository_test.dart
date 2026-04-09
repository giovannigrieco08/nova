import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/safety/data/repositories/tos_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late TosRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseStorageClient mockStorage;
  late MockStorageFileApi mockStorageFileApi;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    mockStorageFileApi = MockStorageFileApi();

    when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
    when(() => mockStorage.from('public')).thenAnswer((_) => mockStorageFileApi);

    repository = TosRepository(supabase: mockSupabase);
  });

  group('getTosStatus', () {
    test('returns TosStatus from RPC response', () async {
      final fb = mockFilterChain<Map<String, dynamic>>({
        'has_accepted': true,
        'accepted_version': '1.0.0',
        'current_version': '1.0.0',
        'needs_reaccept': false,
        'accepted_at': '2025-06-01T00:00:00.000',
      });
      when(() => mockSupabase.rpc('get_tos_status')).thenAnswer((_) => fb);

      final result = await repository.getTosStatus();

      expect(result.hasAccepted, true);
      expect(result.acceptedVersion, '1.0.0');
      expect(result.needsReaccept, false);
      expect(result.canCreateContent, true);
    });

    test('returns initial status when RPC returns null', () async {
      final fb = mockFilterChain<Map<String, dynamic>?>(null);
      when(() => mockSupabase.rpc('get_tos_status')).thenAnswer((_) => fb);

      final result = await repository.getTosStatus();

      expect(result.hasAccepted, false);
      expect(result.needsReaccept, true);
      expect(result.canCreateContent, false);
    });
  });

  group('acceptTos', () {
    test('calls RPC and returns TosAcceptResponse', () async {
      final fb = mockFilterChain<Map<String, dynamic>>({
        'success': true,
        'accepted_version': '1.0.0',
        'accepted_at': '2025-06-01T12:00:00.000',
      });
      when(() => mockSupabase.rpc('accept_tos',
          params: {'p_version': '1.0.0'})).thenAnswer((_) => fb);

      final result = await repository.acceptTos();

      expect(result.success, true);
      expect(result.acceptedVersion, '1.0.0');
    });

    test('accepts specific version when provided', () async {
      final fb = mockFilterChain<Map<String, dynamic>>({
        'success': true,
        'accepted_version': '2.0.0',
        'accepted_at': '2025-06-01T12:00:00.000',
      });
      when(() => mockSupabase.rpc('accept_tos',
          params: {'p_version': '2.0.0'})).thenAnswer((_) => fb);

      final result = await repository.acceptTos(version: '2.0.0');

      expect(result.acceptedVersion, '2.0.0');
    });
  });

  group('getTosDocumentUrl', () {
    test('returns public URL for current version', () {
      when(() => mockStorageFileApi.getPublicUrl('legal/tos-1.0.0.md'))
          .thenReturn('https://cdn.example.com/public/legal/tos-1.0.0.md');

      final result = repository.getTosDocumentUrl();

      expect(result, contains('tos-1.0.0.md'));
    });
  });

  group('hasAcceptedCurrentTos', () {
    test('returns true when user can create content', () async {
      final fb = mockFilterChain<Map<String, dynamic>>({
        'has_accepted': true,
        'accepted_version': '1.0.0',
        'current_version': '1.0.0',
        'needs_reaccept': false,
      });
      when(() => mockSupabase.rpc('get_tos_status')).thenAnswer((_) => fb);

      expect(await repository.hasAcceptedCurrentTos(), true);
    });

    test('returns false when not accepted', () async {
      final fb = mockFilterChain<Map<String, dynamic>?>(null);
      when(() => mockSupabase.rpc('get_tos_status')).thenAnswer((_) => fb);

      expect(await repository.hasAcceptedCurrentTos(), false);
    });
  });
}
