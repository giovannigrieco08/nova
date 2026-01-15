// Core Constants: School Classes
// Feature: 002-profile-setup
// Purpose: Hardcoded list of all classes at Liceo Galilei Moro (35 total)

/// Data class representing a school class
class SchoolClass {
  final String id;
  final String displayName;
  final String track; // "SCIENTIFICO" or "CLASSICO"
  final int year; // 1-5
  final String section; // "A", "B", "C", "D", "F"

  const SchoolClass({
    required this.id,
    required this.displayName,
    required this.track,
    required this.year,
    required this.section,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolClass &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}

/// Complete list of all classes at Liceo Galilei Moro
/// Format: "{year}{section} {track}" (e.g., "3A Scientifico")
/// Total: 33 classes (23 SCIENTIFICO + 10 CLASSICO)
/// Note: Section F exists only for years 1, 2, and 5
const List<SchoolClass> allClasses = [
  // ============================================================================
  // SCIENTIFICO - Year 1 (5 classes: A, B, C, D, F)
  // ============================================================================
  SchoolClass(
    id: '1A Scientifico',
    displayName: '1A Scientifico',
    track: 'SCIENTIFICO',
    year: 1,
    section: 'A',
  ),
  SchoolClass(
    id: '1B Scientifico',
    displayName: '1B Scientifico',
    track: 'SCIENTIFICO',
    year: 1,
    section: 'B',
  ),
  SchoolClass(
    id: '1C Scientifico',
    displayName: '1C Scientifico',
    track: 'SCIENTIFICO',
    year: 1,
    section: 'C',
  ),
  SchoolClass(
    id: '1D Scientifico',
    displayName: '1D Scientifico',
    track: 'SCIENTIFICO',
    year: 1,
    section: 'D',
  ),
  SchoolClass(
    id: '1F Scientifico',
    displayName: '1F Scientifico',
    track: 'SCIENTIFICO',
    year: 1,
    section: 'F',
  ),

  // ============================================================================
  // SCIENTIFICO - Year 2 (5 classes: A, B, C, D, F)
  // ============================================================================
  SchoolClass(
    id: '2A Scientifico',
    displayName: '2A Scientifico',
    track: 'SCIENTIFICO',
    year: 2,
    section: 'A',
  ),
  SchoolClass(
    id: '2B Scientifico',
    displayName: '2B Scientifico',
    track: 'SCIENTIFICO',
    year: 2,
    section: 'B',
  ),
  SchoolClass(
    id: '2C Scientifico',
    displayName: '2C Scientifico',
    track: 'SCIENTIFICO',
    year: 2,
    section: 'C',
  ),
  SchoolClass(
    id: '2D Scientifico',
    displayName: '2D Scientifico',
    track: 'SCIENTIFICO',
    year: 2,
    section: 'D',
  ),
  SchoolClass(
    id: '2F Scientifico',
    displayName: '2F Scientifico',
    track: 'SCIENTIFICO',
    year: 2,
    section: 'F',
  ),

  // ============================================================================
  // SCIENTIFICO - Year 3 (4 classes: A, B, C, D)
  // ============================================================================
  SchoolClass(
    id: '3A Scientifico',
    displayName: '3A Scientifico',
    track: 'SCIENTIFICO',
    year: 3,
    section: 'A',
  ),
  SchoolClass(
    id: '3B Scientifico',
    displayName: '3B Scientifico',
    track: 'SCIENTIFICO',
    year: 3,
    section: 'B',
  ),
  SchoolClass(
    id: '3C Scientifico',
    displayName: '3C Scientifico',
    track: 'SCIENTIFICO',
    year: 3,
    section: 'C',
  ),
  SchoolClass(
    id: '3D Scientifico',
    displayName: '3D Scientifico',
    track: 'SCIENTIFICO',
    year: 3,
    section: 'D',
  ),

  // ============================================================================
  // SCIENTIFICO - Year 4 (4 classes: A, B, C, D)
  // ============================================================================
  SchoolClass(
    id: '4A Scientifico',
    displayName: '4A Scientifico',
    track: 'SCIENTIFICO',
    year: 4,
    section: 'A',
  ),
  SchoolClass(
    id: '4B Scientifico',
    displayName: '4B Scientifico',
    track: 'SCIENTIFICO',
    year: 4,
    section: 'B',
  ),
  SchoolClass(
    id: '4C Scientifico',
    displayName: '4C Scientifico',
    track: 'SCIENTIFICO',
    year: 4,
    section: 'C',
  ),
  SchoolClass(
    id: '4D Scientifico',
    displayName: '4D Scientifico',
    track: 'SCIENTIFICO',
    year: 4,
    section: 'D',
  ),

  // ============================================================================
  // SCIENTIFICO - Year 5 (5 classes: A, B, C, D, F)
  // ============================================================================
  SchoolClass(
    id: '5A Scientifico',
    displayName: '5A Scientifico',
    track: 'SCIENTIFICO',
    year: 5,
    section: 'A',
  ),
  SchoolClass(
    id: '5B Scientifico',
    displayName: '5B Scientifico',
    track: 'SCIENTIFICO',
    year: 5,
    section: 'B',
  ),
  SchoolClass(
    id: '5C Scientifico',
    displayName: '5C Scientifico',
    track: 'SCIENTIFICO',
    year: 5,
    section: 'C',
  ),
  SchoolClass(
    id: '5D Scientifico',
    displayName: '5D Scientifico',
    track: 'SCIENTIFICO',
    year: 5,
    section: 'D',
  ),
  SchoolClass(
    id: '5F Scientifico',
    displayName: '5F Scientifico',
    track: 'SCIENTIFICO',
    year: 5,
    section: 'F',
  ),

  // ============================================================================
  // CLASSICO - Year 1 (2 classes: A, B)
  // ============================================================================
  SchoolClass(
    id: '1A Classico',
    displayName: '1A Classico',
    track: 'CLASSICO',
    year: 1,
    section: 'A',
  ),
  SchoolClass(
    id: '1B Classico',
    displayName: '1B Classico',
    track: 'CLASSICO',
    year: 1,
    section: 'B',
  ),

  // ============================================================================
  // CLASSICO - Year 2 (2 classes: A, B)
  // ============================================================================
  SchoolClass(
    id: '2A Classico',
    displayName: '2A Classico',
    track: 'CLASSICO',
    year: 2,
    section: 'A',
  ),
  SchoolClass(
    id: '2B Classico',
    displayName: '2B Classico',
    track: 'CLASSICO',
    year: 2,
    section: 'B',
  ),

  // ============================================================================
  // CLASSICO - Year 3 (2 classes: A, B)
  // ============================================================================
  SchoolClass(
    id: '3A Classico',
    displayName: '3A Classico',
    track: 'CLASSICO',
    year: 3,
    section: 'A',
  ),
  SchoolClass(
    id: '3B Classico',
    displayName: '3B Classico',
    track: 'CLASSICO',
    year: 3,
    section: 'B',
  ),

  // ============================================================================
  // CLASSICO - Year 4 (2 classes: A, B)
  // ============================================================================
  SchoolClass(
    id: '4A Classico',
    displayName: '4A Classico',
    track: 'CLASSICO',
    year: 4,
    section: 'A',
  ),
  SchoolClass(
    id: '4B Classico',
    displayName: '4B Classico',
    track: 'CLASSICO',
    year: 4,
    section: 'B',
  ),

  // ============================================================================
  // CLASSICO - Year 5 (2 classes: A, B)
  // ============================================================================
  SchoolClass(
    id: '5A Classico',
    displayName: '5A Classico',
    track: 'CLASSICO',
    year: 5,
    section: 'A',
  ),
  SchoolClass(
    id: '5B Classico',
    displayName: '5B Classico',
    track: 'CLASSICO',
    year: 5,
    section: 'B',
  ),
];

/// Helper: Get classes grouped by track
Map<String, List<SchoolClass>> get classesByTrack => {
      'SCIENTIFICO': allClasses.where((c) => c.track == 'SCIENTIFICO').toList(),
      'CLASSICO': allClasses.where((c) => c.track == 'CLASSICO').toList(),
    };

/// Helper: Find class by ID
SchoolClass? getClassById(String id) {
  try {
    return allClasses.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}
