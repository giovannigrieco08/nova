import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/event_help_request_model.dart';
import 'package:nova/features/events/domain/entities/event_help_request.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);
  final nowIso = now.toIso8601String();

  group('EventHelpRequestModel', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('fromJson creates model from valid JSON', () {
      final json = {
        'id': 'req-001',
        'event_id': 'event-001',
        'description': 'Looking for a photographer',
        'is_fulfilled': false,
        'fulfilled_by': null,
        'created_at': nowIso,
        'updated_at': nowIso,
        'pending_offers_count': 3,
      };

      final model = EventHelpRequestModel.fromJson(json);

      expect(model.id, 'req-001');
      expect(model.eventId, 'event-001');
      expect(model.description, 'Looking for a photographer');
      expect(model.isFulfilled, isFalse);
      expect(model.fulfilledBy, isNull);
      expect(model.pendingOffersCount, 3);
    });

    test('toJson produces correct output', () {
      final model = EventHelpRequestModel(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Need DJ for the event',
        isFulfilled: true,
        fulfilledBy: 'user-002',
        createdAt: now,
        updatedAt: now,
        pendingOffersCount: 0,
      );

      final json = model.toJson();

      expect(json['id'], 'req-001');
      expect(json['event_id'], 'event-001');
      expect(json['description'], 'Need DJ for the event');
      expect(json['is_fulfilled'], isTrue);
      expect(json['fulfilled_by'], 'user-002');
      expect(json['created_at'], nowIso);
      expect(json['updated_at'], nowIso);
      // Note: toJson does not include pending_offers_count (computed field)
      expect(json.containsKey('pending_offers_count'), isFalse);
    });

    test('toEntity and fromEntity roundtrip preserves data', () {
      final entity = EventHelpRequest(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Need photographer',
        isFulfilled: false,
        createdAt: now,
        updatedAt: now,
        pendingOffersCount: 5,
      );

      final model = EventHelpRequestModel.fromEntity(entity);
      final restored = model.toEntity();

      expect(restored.id, entity.id);
      expect(restored.eventId, entity.eventId);
      expect(restored.description, entity.description);
      expect(restored.isFulfilled, entity.isFulfilled);
      expect(restored.pendingOffersCount, entity.pendingOffersCount);
    });

    // =====================================================================
    // Edge Case Tests (E:4)
    // =====================================================================

    test('fromJson defaults isFulfilled to false and pendingOffersCount to 0 when missing', () {
      final json = {
        'id': 'req-001',
        'event_id': 'event-001',
        'description': 'Help needed',
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      final model = EventHelpRequestModel.fromJson(json);

      expect(model.isFulfilled, isFalse);
      expect(model.pendingOffersCount, 0);
      expect(model.fulfilledBy, isNull);
    });

    test('EventHelpOfferModel fromJson handles joined profile data', () {
      final json = {
        'id': 'offer-001',
        'request_id': 'req-001',
        'user_id': 'user-002',
        'message': 'I can help!',
        'contact_type': 'instagram',
        'contact_info': '@photo_pro',
        'status': 'pending',
        'created_at': nowIso,
        'updated_at': nowIso,
        'profile': {
          'full_name': 'Lucia Bianchi',
          'class': '3B',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };

      final model = EventHelpOfferModel.fromJson(json);

      expect(model.id, 'offer-001');
      expect(model.userName, 'Lucia Bianchi');
      expect(model.userClass, '3B');
      expect(model.userAvatarUrl, 'https://example.com/avatar.jpg');
      expect(model.message, 'I can help!');
    });

    test('EventHelpOfferModel fromJson handles missing profile and optional fields', () {
      final json = {
        'id': 'offer-002',
        'request_id': 'req-001',
        'user_id': 'user-003',
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      final model = EventHelpOfferModel.fromJson(json);

      expect(model.userName, isNull);
      expect(model.userClass, isNull);
      expect(model.userAvatarUrl, isNull);
      expect(model.message, isNull);
      expect(model.contactType, 'instagram'); // default
      expect(model.contactInfo, ''); // default
      expect(model.status, 'pending'); // default
    });

    test('EventHelpOfferModel toEntity and fromEntity roundtrip', () {
      final entity = EventHelpOffer(
        id: 'offer-001',
        requestId: 'req-001',
        userId: 'user-002',
        message: 'Happy to help',
        contactType: 'whatsapp',
        contactInfo: '+393331234567',
        status: 'accepted',
        createdAt: now,
        updatedAt: now,
        userName: 'Mario Rossi',
        userClass: '4A',
      );

      final model = EventHelpOfferModel.fromEntity(entity);
      final restored = model.toEntity();

      expect(restored.id, entity.id);
      expect(restored.requestId, entity.requestId);
      expect(restored.userId, entity.userId);
      expect(restored.message, entity.message);
      expect(restored.contactType, entity.contactType);
      expect(restored.contactInfo, entity.contactInfo);
      expect(restored.status, entity.status);
      expect(restored.userName, entity.userName);
      expect(restored.userClass, entity.userClass);
    });
  });
}
