import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final _databaseName = "dance_team.db";
  static final _databaseVersion = 1;

  // Numele tabelelor
  static final tableMembers = 'members';
  static final tableAttendance = 'attendance';

  // Coloanele pentru tabela members
  static final columnMemberId = 'id';
  static final columnMemberName = 'name';

  // Coloanele pentru tabela attendance
  static final columnAttendanceId = 'id';
  static final columnMemberIdFK = 'member_id';
  static final columnDate = 'date';
  static final columnPresent = 'present';

  // Constructor privat pentru singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // Crearea tabelei members
    await db.execute('''
      CREATE TABLE $tableMembers (
        $columnMemberId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnMemberName TEXT NOT NULL
      )
    ''');
    // Crearea tabelei attendance
    await db.execute('''
      CREATE TABLE $tableAttendance (
        $columnAttendanceId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnMemberIdFK INTEGER NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnPresent INTEGER NOT NULL,
        FOREIGN KEY ($columnMemberIdFK) REFERENCES $tableMembers ($columnMemberId)
      )
    ''');
  }

  // Funcții pentru gestionarea membrilor
  Future<int> insertMember(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableMembers, row);
  }

  Future<List<Map<String, dynamic>>> queryAllMembers() async {
    Database db = await instance.database;
    return await db.query(tableMembers);
  }

  Future<int> deleteMember(int id) async {
    Database db = await instance.database;
    return await db.delete(tableMembers, where: '$columnMemberId = ?', whereArgs: [id]);
  }

  // Funcții pentru gestionarea prezenței
  Future<int> insertOrUpdateAttendance(Map<String, dynamic> row) async {
    Database db = await instance.database;
    // Verifică dacă există deja un record pentru acel membru și data aleasă
    List<Map<String, dynamic>> results = await db.query(
      tableAttendance,
      where: '$columnMemberIdFK = ? AND $columnDate = ?',
      whereArgs: [row[columnMemberIdFK], row[columnDate]],
    );
    if (results.isEmpty) {
      // Dacă nu există, inserează record-ul nou
      return await db.insert(tableAttendance, row);
    } else {
      // Dacă există, actualizează record-ul existent
      int id = results.first[columnAttendanceId];
      return await db.update(tableAttendance, row, where: '$columnAttendanceId = ?', whereArgs: [id]);
    }
  }

  Future<List<Map<String, dynamic>>> queryAttendanceByDate(String date) async {
    Database db = await instance.database;
    return await db.query(tableAttendance, where: '$columnDate = ?', whereArgs: [date]);
  }
}
