/// Mirrors `src/app/data/mockData.ts` — departments, years, courses for Register / Onboarding.
library registration_mock_data;

class RegistrationDepartment {
  const RegistrationDepartment({required this.id, required this.name});
  final String id;
  final String name;
}

class RegistrationYear {
  const RegistrationYear({required this.id, required this.name});
  final int id;
  final String name;
}

class RegistrationCourse {
  const RegistrationCourse({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;
}

abstract final class RegistrationMockData {
  /// İskelet liste  ileride backend `GET /reference/departments` ile değiştirilecek.
  static const departments = <RegistrationDepartment>[
    RegistrationDepartment(id: 'cse', name: 'Computer Engineering'),
    RegistrationDepartment(id: 'ie', name: 'Industrial Engineering'),
    RegistrationDepartment(id: 'math', name: 'Mathematics'),
  ];

  static const yearLevels = <RegistrationYear>[
    RegistrationYear(id: 1, name: '1st Year'),
    RegistrationYear(id: 2, name: '2nd Year'),
    RegistrationYear(id: 3, name: '3rd Year'),
    RegistrationYear(id: 4, name: '4th Year'),
  ];

  static const courses = <RegistrationCourse>[
    RegistrationCourse(id: 'cse101', code: 'CSE101', name: 'Computer Engineering Concepts and Algorithms'),
    RegistrationCourse(id: 'gbe113', code: 'GBE113', name: 'Fundamental Biology'),
    RegistrationCourse(id: 'math131', code: 'MATH131', name: 'Calculus I'),
    RegistrationCourse(id: 'phys101', code: 'PHYS101', name: 'Physics I'),
    RegistrationCourse(id: 'cse114', code: 'CSE114', name: 'Fundamentals Of Computer Programming'),
    RegistrationCourse(id: 'math132', code: 'MATH132', name: 'Calculus II'),
    RegistrationCourse(id: 'math154', code: 'MATH154', name: 'Discrete Mathematics'),
    RegistrationCourse(id: 'phys102', code: 'PHYS102', name: 'Physics II'),
    RegistrationCourse(id: 'cse211', code: 'CSE211', name: 'Data Structures'),
    RegistrationCourse(id: 'cse221', code: 'CSE221', name: 'Principles of Logic Design'),
    RegistrationCourse(id: 'ee211', code: 'EE211', name: 'Electrical Circuits'),
    RegistrationCourse(id: 'hum103', code: 'HUM103', name: 'Humanities'),
    RegistrationCourse(id: 'math221', code: 'MATH221', name: 'Linear Algebra'),
    RegistrationCourse(id: 'cse212', code: 'CSE212', name: 'Software Development Methodologies'),
    RegistrationCourse(id: 'cse224', code: 'CSE224', name: 'Introduction to Digital Systems'),
    RegistrationCourse(id: 'cse232', code: 'CSE232', name: 'Systems Programming'),
    RegistrationCourse(id: 'math241', code: 'MATH241', name: 'Differential Equations'),
    RegistrationCourse(id: 'math281', code: 'MATH281', name: 'Probability'),
    RegistrationCourse(id: 'cse311', code: 'CSE311', name: 'Analysis Of Algorithms'),
    RegistrationCourse(id: 'cse323', code: 'CSE323', name: 'Computer Organization'),
    RegistrationCourse(id: 'es224', code: 'ES224', name: 'File Organization'),
    RegistrationCourse(id: 'cse351', code: 'CSE351', name: 'Programming Languages'),
    RegistrationCourse(id: 'es224-2', code: 'ES224', name: 'Signals and Systems'),
    RegistrationCourse(id: 'htr301', code: 'HTR301', name: 'History of Turkish Revolution I'),
    RegistrationCourse(id: 'cse331', code: 'CSE331', name: 'Operating Systems Design'),
    RegistrationCourse(id: 'cse344', code: 'CSE344', name: 'Software Engineering'),
    RegistrationCourse(id: 'cse348', code: 'CSE348', name: 'Database Management Systems'),
    RegistrationCourse(id: 'cse354', code: 'CSE354', name: 'Automata Theory & Formal Languages'),
    RegistrationCourse(id: 'htr302', code: 'HTR302', name: 'History of Turkish Revolution II'),
    RegistrationCourse(id: 'cse400', code: 'CSE400', name: 'Summer Practice'),
    RegistrationCourse(id: 'cse471', code: 'CSE471', name: 'Data Communications & Computer Networks'),
    RegistrationCourse(id: 'cse492', code: 'CSE492', name: 'Engineering Project'),
  ];
}
