import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shift.dart';
import '../models/salary_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shifts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        startMinutes INTEGER,
        endMinutes INTEGER,
        hoursWorked REAL NOT NULL,
        shiftType TEXT NOT NULL,
        regularHours REAL NOT NULL DEFAULT 0,
        overtimeHours REAL NOT NULL DEFAULT 0,
        isHoliday INTEGER NOT NULL DEFAULT 0,
        specialPayMultiplier REAL NOT NULL DEFAULT 1.0,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE salary_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periodStart TEXT NOT NULL,
        periodEnd TEXT NOT NULL,
        totalHours REAL NOT NULL,
        ratePerHour REAL NOT NULL,
        totalSalary REAL NOT NULL,
        shiftCount INTEGER NOT NULL,
        periodType TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE archived_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salaryRecordId INTEGER NOT NULL,
        date TEXT NOT NULL,
        startMinutes INTEGER,
        endMinutes INTEGER,
        hoursWorked REAL NOT NULL,
        shiftType TEXT NOT NULL,
        regularHours REAL NOT NULL DEFAULT 0,
        overtimeHours REAL NOT NULL DEFAULT 0,
        isHoliday INTEGER NOT NULL DEFAULT 0,
        specialPayMultiplier REAL NOT NULL DEFAULT 1.0,
        FOREIGN KEY (salaryRecordId) REFERENCES salary_records (id) ON DELETE CASCADE
      )
    ''');

    // Set default rate per hour and last period checked
    await db.insert('settings', {'key': 'ratePerHour', 'value': '15.0'});
    await db.insert('settings', {'key': 'overtimeMultiplier', 'value': '1.5'});
    await db.insert('settings', {
      'key': 'lastPeriodCheck',
      'value': DateTime.now().toIso8601String(),
    });
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add shiftType column to existing shifts table
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN shiftType TEXT DEFAULT "Opening Shift"',
      );

      // Remove ratePerHour column by recreating table
      await db.execute('ALTER TABLE shifts RENAME TO shifts_old');
      await db.execute('''
        CREATE TABLE shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          hoursWorked REAL NOT NULL,
          shiftType TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO shifts (id, date, hoursWorked, shiftType)
        SELECT id, date, hoursWorked, "Opening Shift" FROM shifts_old
      ''');
      await db.execute('DROP TABLE shifts_old');

      // Create settings table
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert('settings', {'key': 'ratePerHour', 'value': '15.0'});
    }

    if (oldVersion < 3) {
      // Add salary_records table
      await db.execute('''
        CREATE TABLE salary_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          periodStart TEXT NOT NULL,
          periodEnd TEXT NOT NULL,
          totalHours REAL NOT NULL,
          ratePerHour REAL NOT NULL,
          totalSalary REAL NOT NULL,
          shiftCount INTEGER NOT NULL,
          periodType TEXT NOT NULL
        )
      ''');

      // Add last period check setting
      await db.insert('settings', {
        'key': 'lastPeriodCheck',
        'value': DateTime.now().toIso8601String(),
      });
    }

    if (oldVersion < 4) {
      // Add archived_shifts table
      await db.execute('''
        CREATE TABLE archived_shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          salaryRecordId INTEGER NOT NULL,
          date TEXT NOT NULL,
          hoursWorked REAL NOT NULL,
          shiftType TEXT NOT NULL,
          FOREIGN KEY (salaryRecordId) REFERENCES salary_records (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 5) {
      // Add overtime fields to shifts table
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN regularHours REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN overtimeHours REAL NOT NULL DEFAULT 0',
      );

      // Update existing shifts to set regularHours and overtimeHours
      await db.execute('''
        UPDATE shifts 
        SET regularHours = CASE WHEN hoursWorked <= 8 THEN hoursWorked ELSE 8 END,
            overtimeHours = CASE WHEN hoursWorked > 8 THEN hoursWorked - 8 ELSE 0 END
      ''');

      // Add archived_shifts overtime fields
      await db.execute(
        'ALTER TABLE archived_shifts ADD COLUMN regularHours REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE archived_shifts ADD COLUMN overtimeHours REAL NOT NULL DEFAULT 0',
      );

      // Update existing archived shifts
      await db.execute('''
        UPDATE archived_shifts 
        SET regularHours = CASE WHEN hoursWorked <= 8 THEN hoursWorked ELSE 8 END,
            overtimeHours = CASE WHEN hoursWorked > 8 THEN hoursWorked - 8 ELSE 0 END
      ''');

      // Add overtime multiplier setting
      await db.insert('settings', {
        'key': 'overtimeMultiplier',
        'value': '1.5',
      });
    }

    if (oldVersion < 6) {
      // Add holiday and special pay fields
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN isHoliday INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN specialPayMultiplier REAL NOT NULL DEFAULT 1.0',
      );

      // Add to archived_shifts as well
      await db.execute(
        'ALTER TABLE archived_shifts ADD COLUMN isHoliday INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE archived_shifts ADD COLUMN specialPayMultiplier REAL NOT NULL DEFAULT 1.0',
      );
    }

    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE shifts ADD COLUMN isCompleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE shifts ADD COLUMN completedAt TEXT');

      // Some installs created at v6 may have an older archived_shifts schema.
      // Add the latest columns defensively.
      for (final statement in <String>[
        'ALTER TABLE archived_shifts ADD COLUMN regularHours REAL NOT NULL DEFAULT 0',
        'ALTER TABLE archived_shifts ADD COLUMN overtimeHours REAL NOT NULL DEFAULT 0',
        'ALTER TABLE archived_shifts ADD COLUMN isHoliday INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE archived_shifts ADD COLUMN specialPayMultiplier REAL NOT NULL DEFAULT 1.0',
      ]) {
        try {
          await db.execute(statement);
        } catch (_) {
          // Ignore if the column already exists.
        }
      }
    }

    if (oldVersion < 8) {
      for (final statement in <String>[
        'ALTER TABLE shifts ADD COLUMN startMinutes INTEGER',
        'ALTER TABLE shifts ADD COLUMN endMinutes INTEGER',
        'ALTER TABLE archived_shifts ADD COLUMN startMinutes INTEGER',
        'ALTER TABLE archived_shifts ADD COLUMN endMinutes INTEGER',
      ]) {
        try {
          await db.execute(statement);
        } catch (_) {
          // Ignore if the column already exists.
        }
      }
    }
  }

  Future<int> insertShift(Shift shift) async {
    final db = await database;
    return await db.insert('shifts', shift.toMap());
  }

  Future<List<Shift>> getAllShifts() async {
    final db = await database;
    final result = await db.query('shifts', orderBy: 'date DESC');
    return result.map((map) => Shift.fromMap(map)).toList();
  }

  Future<List<Shift>> getActiveShifts() async {
    final db = await database;
    final result = await db.query(
      'shifts',
      where: 'isCompleted = 0',
      orderBy: 'date DESC',
    );
    return result.map((map) => Shift.fromMap(map)).toList();
  }

  Future<List<Shift>> getCompletedShifts() async {
    final db = await database;
    final result = await db.query(
      'shifts',
      where: 'isCompleted = 1',
      orderBy: 'completedAt DESC, date DESC',
    );
    return result.map((map) => Shift.fromMap(map)).toList();
  }

  Future<int> getCompletedShiftCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM shifts WHERE isCompleted = 1',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<double> getCompletedShiftTotalHours() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(hoursWorked), 0) as s FROM shifts WHERE isCompleted = 1',
    );
    final value = result.first['s'];
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<int> markShiftCompleted(int id, DateTime completedAt) async {
    final db = await database;
    return await db.update(
      'shifts',
      {'isCompleted': 1, 'completedAt': completedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markShiftCompletedWithHours(
    int id, {
    required DateTime completedAt,
    required double hoursWorked,
    required double overtimeHours,
  }) async {
    final db = await database;
    return await db.update(
      'shifts',
      {
        'hoursWorked': hoursWorked,
        'overtimeHours': overtimeHours,
        'isCompleted': 1,
        'completedAt': completedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteShift(int id) async {
    final db = await database;
    return await db.delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getRatePerHour() async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['ratePerHour'],
    );
    if (result.isNotEmpty) {
      return double.parse(result.first['value'] as String);
    }
    return 15.0; // Default rate
  }

  Future<void> updateRatePerHour(double rate) async {
    final db = await database;
    await db.update(
      'settings',
      {'value': rate.toString()},
      where: 'key = ?',
      whereArgs: ['ratePerHour'],
    );
  }

  Future<double> getOvertimeMultiplier() async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['overtimeMultiplier'],
    );
    if (result.isNotEmpty) {
      return double.parse(result.first['value'] as String);
    }
    return 1.5; // Default 150%
  }

  Future<void> updateOvertimeMultiplier(double multiplier) async {
    final db = await database;
    await db.update(
      'settings',
      {'value': multiplier.toString()},
      where: 'key = ?',
      whereArgs: ['overtimeMultiplier'],
    );
  }

  Future<String?> getSettingValue(String key) async {
    final db = await database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSettingValue(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertSalaryRecord(SalaryRecord record) async {
    final db = await database;
    return await db.insert('salary_records', record.toMap());
  }

  Future<int> insertArchivedShift(int salaryRecordId, Shift shift) async {
    final db = await database;
    return await db.insert('archived_shifts', {
      'salaryRecordId': salaryRecordId,
      'date': shift.date.toIso8601String(),
      'startMinutes': shift.startMinutes,
      'endMinutes': shift.endMinutes,
      'hoursWorked': shift.hoursWorked,
      'shiftType': shift.shiftType,
      'regularHours': shift.regularHours,
      'overtimeHours': shift.overtimeHours,
      'isHoliday': shift.isHoliday ? 1 : 0,
      'specialPayMultiplier': shift.specialPayMultiplier,
    });
  }

  Future<List<Shift>> getAllArchivedShifts() async {
    final db = await database;
    final result = await db.query('archived_shifts', orderBy: 'date DESC');
    return result
        .map(
          (map) => Shift(
            id: map['id'] as int,
            date: DateTime.parse(map['date'] as String),
            startMinutes: map['startMinutes'] as int?,
            endMinutes: map['endMinutes'] as int?,
            hoursWorked: (map['hoursWorked'] as num).toDouble(),
            shiftType: map['shiftType'] as String,
            regularHours: (map['regularHours'] as num?)?.toDouble(),
            overtimeHours: (map['overtimeHours'] as num?)?.toDouble(),
            isHoliday: ((map['isHoliday'] as int?) ?? 0) == 1,
            specialPayMultiplier: ((map['specialPayMultiplier'] as num?) ?? 1.0)
                .toDouble(),
            isCompleted: true,
          ),
        )
        .toList();
  }

  Future<List<Shift>> getArchivedShifts(int salaryRecordId) async {
    final db = await database;
    final result = await db.query(
      'archived_shifts',
      where: 'salaryRecordId = ?',
      whereArgs: [salaryRecordId],
      orderBy: 'date DESC',
    );
    return result
        .map(
          (map) => Shift(
            id: map['id'] as int,
            date: DateTime.parse(map['date'] as String),
            startMinutes: map['startMinutes'] as int?,
            endMinutes: map['endMinutes'] as int?,
            hoursWorked: map['hoursWorked'] as double,
            shiftType: map['shiftType'] as String,
            regularHours: (map['regularHours'] as num?)?.toDouble(),
            overtimeHours: (map['overtimeHours'] as num?)?.toDouble(),
            isHoliday: ((map['isHoliday'] as int?) ?? 0) == 1,
            specialPayMultiplier: ((map['specialPayMultiplier'] as num?) ?? 1.0)
                .toDouble(),
          ),
        )
        .toList();
  }

  Future<List<SalaryRecord>> getAllSalaryRecords() async {
    final db = await database;
    final result = await db.query('salary_records', orderBy: 'periodEnd DESC');
    return result.map((map) => SalaryRecord.fromMap(map)).toList();
  }

  Future<DateTime> getLastPeriodCheck() async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['lastPeriodCheck'],
    );
    if (result.isNotEmpty) {
      return DateTime.parse(result.first['value'] as String);
    }
    return DateTime.now();
  }

  Future<void> updateLastPeriodCheck(DateTime date) async {
    final db = await database;
    await db.update(
      'settings',
      {'value': date.toIso8601String()},
      where: 'key = ?',
      whereArgs: ['lastPeriodCheck'],
    );
  }

  Future<void> deleteAllShifts() async {
    final db = await database;
    await db.delete('shifts');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
