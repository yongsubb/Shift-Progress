class SalaryRecord {
  final int? id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalHours;
  final double ratePerHour;
  final double totalSalary;
  final int shiftCount;
  final String periodType; // '1-15' or '16-end'

  SalaryRecord({
    this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.totalHours,
    required this.ratePerHour,
    required this.totalSalary,
    required this.shiftCount,
    required this.periodType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'totalHours': totalHours,
      'ratePerHour': ratePerHour,
      'totalSalary': totalSalary,
      'shiftCount': shiftCount,
      'periodType': periodType,
    };
  }

  factory SalaryRecord.fromMap(Map<String, dynamic> map) {
    return SalaryRecord(
      id: map['id'],
      periodStart: DateTime.parse(map['periodStart']),
      periodEnd: DateTime.parse(map['periodEnd']),
      totalHours: map['totalHours'],
      ratePerHour: map['ratePerHour'],
      totalSalary: map['totalSalary'],
      shiftCount: map['shiftCount'],
      periodType: map['periodType'],
    );
  }
}
