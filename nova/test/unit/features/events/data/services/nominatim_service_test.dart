import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:nova/features/events/data/services/nominatim_service.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late NominatimService service;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    service = NominatimService(client: mockClient);
  });

  tearDown(() {
    service.dispose();
  });

  // ==========================================================================
  // search
  // ==========================================================================

  group('search', () {
    test('happy: returns list of NominatimPlace on success', () async {
      final responseBody = jsonEncode([
        {
          'place_id': '123',
          'display_name': 'Piazza Duomo, Milano, Lombardia, Italia',
          'lat': '45.464',
          'lon': '9.190',
          'type': 'square',
          'addresstype': 'square',
        },
        {
          'place_id': '456',
          'display_name': 'Piazza San Marco, Venezia, Veneto, Italia',
          'lat': '45.434',
          'lon': '12.338',
          'type': 'square',
          'addresstype': 'square',
        },
      ]);

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      final results = await service.search('Piazza');

      expect(results.length, 2);
      expect(results.first.placeId, '123');
      expect(results.first.lat, 45.464);
      expect(results.first.lon, 9.190);
      expect(results.first.displayName, contains('Piazza Duomo'));
    });

    test('happy: uses correct User-Agent and Accept headers', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200));

      await service.search('Test');

      final captured = verify(
        () => mockClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured.single as Map<String, String>;

      expect(captured['User-Agent'], contains('Nova'));
      expect(captured['Accept'], 'application/json');
    });

    test('happy: returns empty list for empty query', () async {
      final results = await service.search('');

      expect(results, isEmpty);
      verifyNever(() => mockClient.get(any(), headers: any(named: 'headers')));
    });

    test('edge: returns empty list on non-200 status', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Error', 500));

      final results = await service.search('Piazza');

      expect(results, isEmpty);
    });

    test('edge: returns empty list on network exception', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('No internet'));

      final results = await service.search('Piazza');

      expect(results, isEmpty);
    });

    test('edge: returns empty list on malformed JSON', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('not json', 200));

      final results = await service.search('Piazza');

      expect(results, isEmpty);
    });
  });

  // ==========================================================================
  // reverseGeocode
  // ==========================================================================

  group('reverseGeocode', () {
    test('happy: returns NominatimPlace on success', () async {
      final responseBody = jsonEncode({
        'place_id': '789',
        'display_name': 'Via Roma, Roma, Lazio, Italia',
        'lat': '41.9028',
        'lon': '12.4964',
        'type': 'road',
        'addresstype': 'road',
      });

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await service.reverseGeocode(41.9028, 12.4964);

      expect(result, isNotNull);
      expect(result!.placeId, '789');
      expect(result.displayName, contains('Via Roma'));
    });

    test('edge: returns null on non-200 status', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Error', 404));

      final result = await service.reverseGeocode(0.0, 0.0);

      expect(result, isNull);
    });

    test('edge: returns null on network error', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('timeout'));

      final result = await service.reverseGeocode(45.0, 9.0);

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // NominatimPlace helpers
  // ==========================================================================

  group('NominatimPlace', () {
    test('shortName returns first two parts', () {
      final place = NominatimPlace(
        placeId: '1',
        displayName: 'Piazza Duomo, Milano, Lombardia, Italia',
        lat: 45.464,
        lon: 9.190,
      );

      expect(place.shortName, 'Piazza Duomo, Milano');
    });

    test('address returns parts after first two', () {
      final place = NominatimPlace(
        placeId: '1',
        displayName: 'Piazza Duomo, Milano, Lombardia, Italia',
        lat: 45.464,
        lon: 9.190,
      );

      expect(place.address, contains('Lombardia'));
    });

    test('shortName returns full name when less than 2 parts', () {
      final place = NominatimPlace(
        placeId: '1',
        displayName: 'Roma',
        lat: 41.9,
        lon: 12.5,
      );

      expect(place.shortName, 'Roma');
    });

    test('address returns null when less than 3 parts', () {
      final place = NominatimPlace(
        placeId: '1',
        displayName: 'Roma, Italia',
        lat: 41.9,
        lon: 12.5,
      );

      expect(place.address, isNull);
    });
  });
}
