import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/event_help_request.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('EventHelpRequest', () {
    // =====================================================================
    // Happy Path Tests (H:4)
    // =====================================================================

    test('should create EventHelpRequest with required fields', () {
      final request = EventHelpRequest(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Looking for a photographer',
        createdAt: now,
        updatedAt: now,
      );

      expect(request.id, 'req-001');
      expect(request.eventId, 'event-001');
      expect(request.description, 'Looking for a photographer');
      expect(request.isFulfilled, isFalse);
      expect(request.fulfilledBy, isNull);
      expect(request.pendingOffersCount, 0);
    });

    test('isOpen returns true when not fulfilled', () {
      final request = EventHelpRequest(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Need DJ',
        createdAt: now,
        updatedAt: now,
        isFulfilled: false,
      );

      expect(request.isOpen, isTrue);
    });

    test('isOpen returns false when fulfilled', () {
      final request = EventHelpRequest(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Need DJ',
        createdAt: now,
        updatedAt: now,
        isFulfilled: true,
        fulfilledBy: 'user-002',
      );

      expect(request.isOpen, isFalse);
    });

    test('EventHelpOffer status getters work correctly', () {
      final pendingOffer = EventHelpOffer(
        id: 'offer-001',
        requestId: 'req-001',
        userId: 'user-002',
        contactType: 'instagram',
        contactInfo: '@test_user',
        status: HelpOfferStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final acceptedOffer = pendingOffer.copyWith(status: HelpOfferStatus.accepted);
      final declinedOffer = pendingOffer.copyWith(status: HelpOfferStatus.declined);

      expect(pendingOffer.isPending, isTrue);
      expect(pendingOffer.isAccepted, isFalse);
      expect(pendingOffer.isDeclined, isFalse);

      expect(acceptedOffer.isPending, isFalse);
      expect(acceptedOffer.isAccepted, isTrue);

      expect(declinedOffer.isPending, isFalse);
      expect(declinedOffer.isDeclined, isTrue);
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('defaults isFulfilled to false and pendingOffersCount to 0', () {
      final request = EventHelpRequest(
        id: 'req-001',
        eventId: 'event-001',
        description: 'Help needed',
        createdAt: now,
        updatedAt: now,
      );

      expect(request.isFulfilled, false);
      expect(request.pendingOffersCount, 0);
    });

    test('EventHelpOffer defaults status to pending', () {
      final offer = EventHelpOffer(
        id: 'offer-001',
        requestId: 'req-001',
        userId: 'user-002',
        contactType: 'whatsapp',
        contactInfo: '+393331234567',
        createdAt: now,
        updatedAt: now,
      );

      expect(offer.status, 'pending');
      expect(offer.message, isNull);
      expect(offer.userName, isNull);
      expect(offer.userClass, isNull);
      expect(offer.userAvatarUrl, isNull);
    });

    test('HelpOfferStatus constants have expected values', () {
      expect(HelpOfferStatus.pending, 'pending');
      expect(HelpOfferStatus.accepted, 'accepted');
      expect(HelpOfferStatus.declined, 'declined');
    });
  });
}
