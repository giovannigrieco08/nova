import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/events/domain/usecases/get_events_feed.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import '../../../../../fixtures/test_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late GetEventsFeed useCase;
  late MockEventsRepository mockRepository;

  setUp(() {
    mockRepository = MockEventsRepository();
    useCase = GetEventsFeed(repository: mockRepository);
  });

  group('execute', () {
    test('happy: returns list of events for valid page and default limit',
        () async {
      final expected = TestEvents.sampleFeed(count: 5);
      when(() => mockRepository.getEventsFeed(
            page: 1,
            limit: 20,
            forceRefresh: false,
          )).thenAnswer((_) async => expected);

      final result = await useCase.execute(page: 1);

      expect(result, expected);
      expect(result.length, 5);
      verify(() => mockRepository.getEventsFeed(
            page: 1,
            limit: 20,
            forceRefresh: false,
          )).called(1);
    });

    test('happy: returns events with custom limit and forceRefresh',
        () async {
      final expected = TestEvents.sampleFeed(count: 3);
      when(() => mockRepository.getEventsFeed(
            page: 2,
            limit: 10,
            forceRefresh: true,
          )).thenAnswer((_) async => expected);

      final result =
          await useCase.execute(page: 2, limit: 10, forceRefresh: true);

      expect(result, expected);
      verify(() => mockRepository.getEventsFeed(
            page: 2,
            limit: 10,
            forceRefresh: true,
          )).called(1);
    });

    test('happy: returns empty list when no events available', () async {
      when(() => mockRepository.getEventsFeed(
            page: 1,
            limit: 20,
            forceRefresh: false,
          )).thenAnswer((_) async => <Event>[]);

      final result = await useCase.execute(page: 1);

      expect(result, isEmpty);
    });

    test('edge: throws ArgumentError when page < 1', () async {
      expect(
        () => useCase.execute(page: 0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Page number must be >= 1',
        )),
      );
      verifyNever(() => mockRepository.getEventsFeed(
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            forceRefresh: any(named: 'forceRefresh'),
          ));
    });

    test('edge: throws ArgumentError when limit > 100', () async {
      expect(
        () => useCase.execute(page: 1, limit: 101),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Limit must be between 1 and 100',
        )),
      );
      verifyNever(() => mockRepository.getEventsFeed(
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            forceRefresh: any(named: 'forceRefresh'),
          ));
    });
  });
}
