/// Subject enum for tutoring subjects.
///
/// Represents the 11 supported school subjects for tutoring at Liceo Galilei Moro.
enum Subject {
  arte('Arte', 'arte', 'Storia dell\'arte, Tecniche artistiche'),
  filosofia('Filosofia', 'filosofia', 'Autori, Correnti, Pensiero critico'),
  fisica('Fisica', 'fisica', 'Meccanica, Termodinamica, Elettromagnetismo'),
  greco('Greco', 'greco', 'Grammatica, Versioni, Letteratura'),
  informatica(
      'Informatica', 'informatica', 'Programmazione, Algoritmi, Database'),
  inglese('Inglese', 'inglese', 'Grammar, Speaking, Writing'),
  italiano('Italiano', 'italiano', 'Letteratura, Grammatica, Scrittura'),
  latino('Latino', 'latino', 'Grammatica, Versioni, Letteratura'),
  matematica('Matematica', 'matematica', 'Algebra, Analisi, Geometria'),
  scienze('Scienze', 'scienze', 'Biologia, Chimica, Scienze della Terra'),
  storia('Storia', 'storia', 'Antica, Medievale, Moderna, Contemporanea');

  /// Display name for UI (Italian).
  final String displayName;

  /// Database value (lowercase).
  final String dbValue;

  /// Description of topics covered.
  final String description;

  const Subject(this.displayName, this.dbValue, this.description);

  /// Parse a database value to Subject enum.
  static Subject? fromDbValue(String value) {
    for (final subject in Subject.values) {
      if (subject.dbValue == value) return subject;
    }
    return null;
  }

  /// Parse a list of database values to Subject list.
  static List<Subject> fromDbValues(List<String> values) {
    return values.map((v) => fromDbValue(v)).whereType<Subject>().toList();
  }
}

/// Availability day enum for tutor scheduling.
enum AvailabilityDay {
  monday('Lunedì', 'monday', 'Lun'),
  tuesday('Martedì', 'tuesday', 'Mar'),
  wednesday('Mercoledì', 'wednesday', 'Mer'),
  thursday('Giovedì', 'thursday', 'Gio'),
  friday('Venerdì', 'friday', 'Ven'),
  saturday('Sabato', 'saturday', 'Sab');

  /// Display name for UI (Italian).
  final String displayName;

  /// Database value (lowercase English).
  final String dbValue;

  /// Short name for compact display (Italian abbreviation).
  final String shortName;

  const AvailabilityDay(this.displayName, this.dbValue, this.shortName);

  /// Parse a database value to AvailabilityDay enum.
  static AvailabilityDay? fromDbValue(String value) {
    for (final day in AvailabilityDay.values) {
      if (day.dbValue == value) return day;
    }
    return null;
  }

  /// Parse a list of database values to AvailabilityDay list.
  static List<AvailabilityDay> fromDbValues(List<String> values) {
    return values
        .map((v) => fromDbValue(v))
        .whereType<AvailabilityDay>()
        .toList();
  }
}
