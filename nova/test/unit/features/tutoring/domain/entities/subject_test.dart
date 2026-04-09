import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/tutoring/domain/entities/subject.dart';

void main() {
  group('Subject', () {
    // ===================== HAPPY PATH =====================

    test('fromDbValue returns correct Subject for known values', () {
      expect(Subject.fromDbValue('matematica'), Subject.matematica);
      expect(Subject.fromDbValue('fisica'), Subject.fisica);
      expect(Subject.fromDbValue('italiano'), Subject.italiano);
      expect(Subject.fromDbValue('inglese'), Subject.inglese);
      expect(Subject.fromDbValue('greco'), Subject.greco);
      expect(Subject.fromDbValue('latino'), Subject.latino);
    });

    test('fromDbValues converts list of strings to Subject list', () {
      final subjects =
          Subject.fromDbValues(['matematica', 'fisica', 'informatica']);

      expect(subjects.length, 3);
      expect(subjects[0], Subject.matematica);
      expect(subjects[1], Subject.fisica);
      expect(subjects[2], Subject.informatica);
    });

    test('enum properties are correct', () {
      expect(Subject.matematica.displayName, 'Matematica');
      expect(Subject.matematica.dbValue, 'matematica');
      expect(Subject.matematica.description,
          'Algebra, Analisi, Geometria');
    });

    // ===================== EDGE CASES =====================

    test('fromDbValue returns null for unknown value', () {
      expect(Subject.fromDbValue('astrofisica'), isNull);
      expect(Subject.fromDbValue(''), isNull);
    });

    test('fromDbValues filters out unknown values', () {
      final subjects =
          Subject.fromDbValues(['matematica', 'nonexistent', 'fisica']);

      expect(subjects.length, 2);
      expect(subjects[0], Subject.matematica);
      expect(subjects[1], Subject.fisica);
    });
  });

  group('AvailabilityDay', () {
    // ===================== HAPPY PATH =====================

    test('fromDbValue returns correct day', () {
      expect(AvailabilityDay.fromDbValue('monday'), AvailabilityDay.monday);
      expect(AvailabilityDay.fromDbValue('saturday'), AvailabilityDay.saturday);
    });

    test('fromDbValues converts list correctly', () {
      final days =
          AvailabilityDay.fromDbValues(['monday', 'wednesday', 'friday']);

      expect(days.length, 3);
      expect(days[0], AvailabilityDay.monday);
      expect(days[1], AvailabilityDay.wednesday);
      expect(days[2], AvailabilityDay.friday);
    });

    test('enum properties are correct', () {
      expect(AvailabilityDay.monday.displayName, 'Luned\u00ec');
      expect(AvailabilityDay.monday.dbValue, 'monday');
      expect(AvailabilityDay.monday.shortName, 'Lun');
    });

    // ===================== EDGE CASES =====================

    test('fromDbValue returns null for unknown value', () {
      expect(AvailabilityDay.fromDbValue('sunday'), isNull);
      expect(AvailabilityDay.fromDbValue(''), isNull);
    });

    test('fromDbValues filters out unknown values', () {
      final days =
          AvailabilityDay.fromDbValues(['monday', 'sunday', 'friday']);

      expect(days.length, 2);
      expect(days[0], AvailabilityDay.monday);
      expect(days[1], AvailabilityDay.friday);
    });
  });
}
