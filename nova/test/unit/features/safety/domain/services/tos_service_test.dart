import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/safety/domain/services/tos_service.dart';
import 'package:nova/features/safety/data/repositories/tos_repository.dart';
import 'package:nova/features/safety/data/models/tos_status.dart';

class MockTosRepository extends Mock implements TosRepository {}

void main() {
  late TosService service;
  late MockTosRepository mockRepository;

  setUp(() {
    mockRepository = MockTosRepository();
    service = TosService(repository: mockRepository);
  });

  final acceptedStatus = TosStatus(
    hasAccepted: true,
    acceptedVersion: '1.0.0',
    currentVersion: '1.0.0',
    needsReaccept: false,
    acceptedAt: DateTime(2025, 6, 1),
  );

  final notAcceptedStatus = TosStatus.initial();

  final needsReacceptStatus = TosStatus(
    hasAccepted: true,
    acceptedVersion: '0.9.0',
    currentVersion: '1.0.0',
    needsReaccept: true,
    acceptedAt: DateTime(2025, 1, 1),
  );

  final testAcceptResponse = TosAcceptResponse(
    success: true,
    acceptedVersion: '1.0.0',
    acceptedAt: DateTime(2025, 6, 1),
  );

  group('TosService', () {
    // ===== HAPPY PATH TESTS =====

    test('canCreateContent returns true when ToS accepted and current',
        () async {
      when(() => mockRepository.getTosStatus())
          .thenAnswer((_) async => acceptedStatus);

      final result = await service.canCreateContent();

      expect(result, isTrue);
      verify(() => mockRepository.getTosStatus()).called(1);
    });

    test('acceptTos returns accept response from repository', () async {
      when(() => mockRepository.acceptTos())
          .thenAnswer((_) async => testAcceptResponse);

      final result = await service.acceptTos();

      expect(result.success, isTrue);
      expect(result.acceptedVersion, equals('1.0.0'));
      verify(() => mockRepository.acceptTos()).called(1);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('needsTosAcceptance returns true when never accepted', () async {
      when(() => mockRepository.getTosStatus())
          .thenAnswer((_) async => notAcceptedStatus);

      final result = await service.needsTosAcceptance();

      expect(result, isTrue);
    });

    test('needsTosAcceptance returns true when version changed (needsReaccept)',
        () async {
      when(() => mockRepository.getTosStatus())
          .thenAnswer((_) async => needsReacceptStatus);

      final result = await service.needsTosAcceptance();

      expect(result, isTrue);
    });
  });
}
