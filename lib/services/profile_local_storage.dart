import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/user.dart';

/// Stores the latest profile data in a relational (SQLite) database.
class ProfileLocalStorage {
  ProfileLocalStorage();

  static const String _dbName = 'profile_cache.db';
  static const int _dbVersion = 1;
  static const String _tableProfile = 'profiles';

  Database? _db;

  Future<void> init() async {
    await _openDb();
  }

  Future<Database> _openDb() async {
    if (_db != null) return _db!;

    final String dbPath = await getDatabasesPath();
    final String fullPath = p.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableProfile (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            balance REAL NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _db!;
  }

  Future<void> saveUser(UserEntity user) async {
    final Database db = await _openDb();
    await db.insert(
      _tableProfile,
      <String, dynamic>{
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'balance': user.balance,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserEntity?> getUser({int? userId}) async {
    final Database db = await _openDb();
    final List<Map<String, dynamic>> rows = await db.query(
      _tableProfile,
      where: userId != null ? 'id = ?' : null,
      whereArgs: userId != null ? <Object>[userId] : null,
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final Map<String, dynamic> row = rows.first;
    return UserEntity(
      id: (row['id'] as num?)?.toInt() ?? 0,
      name: (row['name'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      balance: row['balance'] as num? ?? 0,
    );
  }

  Future<void> clear() async {
    final Database db = await _openDb();
    await db.delete(_tableProfile);
  }

  Future<void> close() async {
    if (_db == null) return;
    await _db!.close();
    _db = null;
  }
}
