import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/models/product_detail_data.dart';

/// Stores prepared product detail snapshots in SQLite for cold-start/offline usage.
class ProductLocalStorage {
  ProductLocalStorage({Duration? defaultTtl}) : _defaultTtl = defaultTtl;

  static const String _dbName = 'product_cache.db';
  static const int _dbVersion = 2;
  static const String _tableProducts = 'products';

  final Duration? _defaultTtl;
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
          CREATE TABLE $_tableProducts (
            id INTEGER PRIMARY KEY,
            type_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            image_url TEXT NOT NULL,
            price REAL NOT NULL,
            available INTEGER NOT NULL,
            updated_at TEXT NOT NULL,
            note TEXT
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_tableProducts ADD COLUMN note TEXT',
          );
        }
      },
    );

    return _db!;
  }

  Future<void> saveProduct(PreparedProductData data) async {
    final Database db = await _openDb();
    await db.insert(
      _tableProducts,
      <String, dynamic>{
        'id': data.id,
        'type_id': data.typeId,
        'name': data.name,
        'description': data.description,
        'image_url': data.imageUrl,
        'price': data.price,
        'available': data.available ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'note': data.note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PreparedProductData?> getProduct(
    int productId, {
    Duration? maxAge,
  }) async {
    final Database db = await _openDb();
    final List<Map<String, dynamic>> rows = await db.query(
      _tableProducts,
      where: 'id = ?',
      whereArgs: <Object>[productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final Map<String, dynamic> row = rows.first;
    final DateTime updatedAt =
        DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final Duration? ttl = maxAge ?? _defaultTtl;
    if (ttl != null && DateTime.now().difference(updatedAt) > ttl) {
      // Expired entry
      return null;
    }

    return PreparedProductData(
      id: (row['id'] as num?)?.toInt() ?? 0,
      typeId: (row['type_id'] as num?)?.toInt() ?? 0,
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      imageUrl: (row['image_url'] ?? '').toString(),
      price: (row['price'] as num?)?.toDouble() ?? 0,
      available: (row['available'] as num?)?.toInt() == 1,
      heroTag: 'product-${(row['id'] as num?)?.toInt() ?? 0}',
      note: (row['note'] ?? '').toString(),
    );
  }

  Future<String> getNote(int productId) async {
    final Database db = await _openDb();
    final List<Map<String, dynamic>> rows = await db.query(
      _tableProducts,
      columns: <String>['note'],
      where: 'id = ?',
      whereArgs: <Object>[productId],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return (rows.first['note'] ?? '').toString();
  }

  Future<void> deleteExpired(Duration maxAge) async {
    final Database db = await _openDb();
    final DateTime threshold = DateTime.now().subtract(maxAge);
    await db.delete(
      _tableProducts,
      where: 'updated_at < ?',
      whereArgs: <Object>[threshold.toIso8601String()],
    );
  }

  Future<void> clear() async {
    final Database db = await _openDb();
    await db.delete(_tableProducts);
  }

  Future<void> close() async {
    if (_db == null) return;
    await _db!.close();
    _db = null;
  }
}
