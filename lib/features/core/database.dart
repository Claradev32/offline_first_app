import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static const _databaseName = 'my_offline_first_app1.db';
  static const _databaseVersion = 1;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create your tables here
    await db.execute('''
      CREATE TABLE todos (
           id INTEGER PRIMARY KEY,
        title TEXT,
        description TEXT,
        isCompleted INTEGER,
        createdAt TEXT,
        updatedAt TEXT,
        publishedAt TEXT,
        isNew INTEGER,
        isUpdated INTEGER
      );
    ''');
  }

  // Implement CRUD operations and other database methods here
}
