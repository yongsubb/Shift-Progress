class Shift {
  final int? id;
  final DateTime date;
  final int? startMinutes;
  final int? endMinutes;
  final double hoursWorked;
  final String shiftType;
  final double regularHours;
  final double overtimeHours;
  final bool isHoliday;
  final double specialPayMultiplier; // 1.0 = normal, 2.0 = double, 1.3 = +30%
  final bool isCompleted;
  final DateTime? completedAt;

  Shift({
    this.id,
    required this.date,
    this.startMinutes,
    this.endMinutes,
    required this.hoursWorked,
    required this.shiftType,
    double? regularHours,
    double? overtimeHours,
    this.isHoliday = false,
    this.specialPayMultiplier = 1.0,
    this.isCompleted = false,
    this.completedAt,
  }) : regularHours = regularHours ?? (hoursWorked <= 8 ? hoursWorked : 8),
       overtimeHours = overtimeHours ?? (hoursWorked > 8 ? hoursWorked - 8 : 0);

  double calculateSalary(
    double ratePerHour, [
    double overtimeMultiplier = 1.5,
  ]) {
    // Calculate base salary
    double regularPay = regularHours * ratePerHour;
    double overtimePay = overtimeHours * ratePerHour * overtimeMultiplier;
    double baseSalary = regularPay + overtimePay;

    // Apply holiday multiplier (doubles the entire pay)
    if (isHoliday) {
      baseSalary *= 2.0;
    }

    // Apply special pay multiplier
    baseSalary *= specialPayMultiplier;

    return baseSalary;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'hoursWorked': hoursWorked,
      'shiftType': shiftType,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'isHoliday': isHoliday ? 1 : 0,
      'specialPayMultiplier': specialPayMultiplier,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'],
      date: DateTime.parse(map['date']),
      startMinutes: (map['startMinutes'] as int?),
      endMinutes: (map['endMinutes'] as int?),
      hoursWorked: map['hoursWorked'],
      shiftType: map['shiftType'] ?? 'Opening Shift',
      regularHours: map['regularHours']?.toDouble(),
      overtimeHours: map['overtimeHours']?.toDouble(),
      isHoliday: (map['isHoliday'] ?? 0) == 1,
      specialPayMultiplier: (map['specialPayMultiplier'] ?? 1.0).toDouble(),
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.tryParse(map['completedAt'] as String),
    );
  }
}
