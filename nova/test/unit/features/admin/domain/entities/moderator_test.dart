import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';

void main() {
  group('Moderator', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields and default values', () {
      const moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Prof Moderatore',
        email: 'moderatore@galileimoro.edu.it',
        className: 'Docente',
      );

      expect(moderator.userId, 'mod-001');
      expect(moderator.fullName, 'Prof Moderatore');
      expect(moderator.email, 'moderatore@galileimoro.edu.it');
      expect(moderator.className, 'Docente');
      expect(moderator.totalReviews, 0);
      expect(moderator.reviewsThisWeek, 0);
      expect(moderator.approvalRatePercent, 0.0);
      expect(moderator.lastReviewAt, isNull);
    });

    test('creates with explicit stats', () {
      final moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Prof Moderatore',
        email: 'mod@galileimoro.edu.it',
        className: 'Docente',
        totalReviews: 50,
        reviewsThisWeek: 12,
        approvalRatePercent: 85.5,
        lastReviewAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(moderator.totalReviews, 50);
      expect(moderator.reviewsThisWeek, 12);
      expect(moderator.approvalRatePercent, 85.5);
    });
  });

  group('ModeratorX extensions', () {
    // ===================== HAPPY PATH =====================

    test('isActive returns true when reviewed within 7 days', () {
      final moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Mod',
        email: 'mod@galileimoro.edu.it',
        className: 'Docente',
        lastReviewAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(moderator.isActive, true);
    });

    test('lastActivityText shows minutes, hours, days, weeks', () {
      Moderator modWithReview(Duration ago) => Moderator(
            userId: 'mod-001',
            fullName: 'Mod',
            email: 'mod@galileimoro.edu.it',
            className: 'Docente',
            lastReviewAt: DateTime.now().subtract(ago),
          );

      expect(modWithReview(const Duration(minutes: 30)).lastActivityText,
          '30m fa');
      expect(
          modWithReview(const Duration(hours: 5)).lastActivityText, '5h fa');
      expect(
          modWithReview(const Duration(days: 3)).lastActivityText, '3g fa');
      expect(
          modWithReview(const Duration(days: 14)).lastActivityText, '2w fa');
    });

    // ===================== EDGE CASES =====================

    test('isActive returns false when lastReviewAt is null', () {
      const moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Mod',
        email: 'mod@galileimoro.edu.it',
        className: 'Docente',
      );

      expect(moderator.isActive, false);
    });

    test('isActive returns false when reviewed more than 7 days ago', () {
      final moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Mod',
        email: 'mod@galileimoro.edu.it',
        className: 'Docente',
        lastReviewAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(moderator.isActive, false);
    });

    test('lastActivityText returns Mai when lastReviewAt is null', () {
      const moderator = Moderator(
        userId: 'mod-001',
        fullName: 'Mod',
        email: 'mod@galileimoro.edu.it',
        className: 'Docente',
      );

      expect(moderator.lastActivityText, 'Mai');
    });
  });
}
