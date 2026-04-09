import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/safety/domain/services/block_service.dart';
import 'package:nova/features/safety/data/repositories/block_repository.dart';
import 'package:nova/features/safety/data/models/user_block.dart';

class MockBlockRepository extends Mock implements BlockRepository {}

void main() {
  late BlockService service;
  late MockBlockRepository mockRepository;

  setUp(() {
    mockRepository = MockBlockRepository();
    service = BlockService(repository: mockRepository);
  });

  final testBlock = UserBlock(
    id: 'block-001',
    blockerId: 'user-001',
    blockedId: 'user-002',
    createdAt: DateTime(2025, 6, 1),
  );

  group('BlockService', () {
    // ===== HAPPY PATH TESTS =====

    test('blockUser blocks a user and returns block record', () async {
      when(() => mockRepository.isUserBlocked(any()))
          .thenAnswer((_) async => false);
      when(() => mockRepository.blockUser(any()))
          .thenAnswer((_) async => testBlock);

      final result = await service.blockUser('user-002');

      expect(result, equals(testBlock));
      verify(() => mockRepository.isUserBlocked('user-002')).called(1);
      verify(() => mockRepository.blockUser('user-002')).called(1);
    });

    test('unblockUser returns true on success', () async {
      when(() => mockRepository.unblockUser(any()))
          .thenAnswer((_) async => true);

      final result = await service.unblockUser('user-002');

      expect(result, isTrue);
      verify(() => mockRepository.unblockUser('user-002')).called(1);
    });

    test('canViewProfile returns true when not blocked by user', () async {
      when(() => mockRepository.isBlockedByUser(any()))
          .thenAnswer((_) async => false);

      final result = await service.canViewProfile('user-002');

      expect(result, isTrue);
      verify(() => mockRepository.isBlockedByUser('user-002')).called(1);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('blockUser throws ArgumentError for empty userId', () async {
      expect(
        () => service.blockUser(''),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockRepository.isUserBlocked(any()));
      verifyNever(() => mockRepository.blockUser(any()));
    });

    test('blockUser throws UserAlreadyBlockedException if already blocked',
        () async {
      when(() => mockRepository.isUserBlocked(any()))
          .thenAnswer((_) async => true);

      expect(
        () => service.blockUser('user-002'),
        throwsA(isA<UserAlreadyBlockedException>()),
      );

      verifyNever(() => mockRepository.blockUser(any()));
    });
  });
}
