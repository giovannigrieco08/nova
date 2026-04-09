/// Tests for SchoolClass constants
///
/// Verifies class data integrity, helper functions, and equality.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/constants/classes.dart';

void main() {
  group('SchoolClass constants', () {
    // =========================================================================
    // HAPPY PATH
    // =========================================================================

    group('allClasses', () {
      test('contains expected total count (happy)', () {
        // 23 SCIENTIFICO + 10 CLASSICO = 33
        expect(allClasses.length, equals(33));
      });

      test('all classes have non-empty fields (happy)', () {
        for (final schoolClass in allClasses) {
          expect(schoolClass.id, isNotEmpty);
          expect(schoolClass.displayName, isNotEmpty);
          expect(schoolClass.track, isNotEmpty);
          expect(schoolClass.section, isNotEmpty);
          expect(schoolClass.year, greaterThanOrEqualTo(1));
          expect(schoolClass.year, lessThanOrEqualTo(5));
        }
      });

      test('all IDs are unique (happy)', () {
        final ids = allClasses.map((c) => c.id).toSet();
        expect(ids.length, equals(allClasses.length));
      });
    });

    group('tracks', () {
      test('SCIENTIFICO has 23 classes (happy)', () {
        final scientifico =
            allClasses.where((c) => c.track == 'SCIENTIFICO').toList();
        expect(scientifico.length, equals(23));
      });

      test('CLASSICO has 10 classes (happy)', () {
        final classico =
            allClasses.where((c) => c.track == 'CLASSICO').toList();
        expect(classico.length, equals(10));
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('SchoolClass equality', () {
      test('same ID means equal (edge)', () {
        const class1 = SchoolClass(
          id: '3A Scientifico',
          displayName: '3A Scientifico',
          track: 'SCIENTIFICO',
          year: 3,
          section: 'A',
        );
        const class2 = SchoolClass(
          id: '3A Scientifico',
          displayName: '3A Scientifico',
          track: 'SCIENTIFICO',
          year: 3,
          section: 'A',
        );

        expect(class1, equals(class2));
        expect(class1.hashCode, equals(class2.hashCode));
      });

      test('different ID means not equal (edge)', () {
        const class1 = SchoolClass(
          id: '3A Scientifico',
          displayName: '3A Scientifico',
          track: 'SCIENTIFICO',
          year: 3,
          section: 'A',
        );
        const class2 = SchoolClass(
          id: '3B Scientifico',
          displayName: '3B Scientifico',
          track: 'SCIENTIFICO',
          year: 3,
          section: 'B',
        );

        expect(class1, isNot(equals(class2)));
      });

      test('toString returns displayName (edge)', () {
        const schoolClass = SchoolClass(
          id: '4B Classico',
          displayName: '4B Classico',
          track: 'CLASSICO',
          year: 4,
          section: 'B',
        );

        expect(schoolClass.toString(), equals('4B Classico'));
      });
    });

    // =========================================================================
    // Helper functions
    // =========================================================================

    group('getClassById', () {
      test('returns correct class for valid ID (happy)', () {
        final result = getClassById('3A Scientifico');

        expect(result, isNotNull);
        expect(result!.year, equals(3));
        expect(result.section, equals('A'));
        expect(result.track, equals('SCIENTIFICO'));
      });

      test('returns null for unknown ID (edge)', () {
        final result = getClassById('6Z Fantasy');

        expect(result, isNull);
      });

      test('returns null for empty string (edge)', () {
        final result = getClassById('');

        expect(result, isNull);
      });
    });

    group('classesByTrack', () {
      test('has both track keys (happy)', () {
        final grouped = classesByTrack;

        expect(grouped.containsKey('SCIENTIFICO'), isTrue);
        expect(grouped.containsKey('CLASSICO'), isTrue);
        expect(grouped.length, equals(2));
      });
    });

    // =========================================================================
    // Section F special cases
    // =========================================================================

    group('section F availability', () {
      test('section F exists only for years 1, 2, and 5 in Scientifico (edge)', () {
        final sectionF = allClasses
            .where((c) => c.section == 'F' && c.track == 'SCIENTIFICO')
            .toList();

        final years = sectionF.map((c) => c.year).toSet();
        expect(years, containsAll([1, 2, 5]));
        expect(years.contains(3), isFalse);
        expect(years.contains(4), isFalse);
      });
    });
  });
}
