import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/product.dart';

/// Stores favorite products selected from search results using SQLite.
class SearchFavoritesDb {
  SearchFavoritesDb._();
  static final SearchFavoritesDb instance = SearchFavoritesDb._();

  static const String _dbName = 'search_favorites.db';
  static const int _dbVersion = 1;
  static const String _table = 'favorites';

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final String path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY,
        type_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        price REAL NOT NULL,
        available INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_favorites_type_id ON $_table(type_id);');
  }

  Future<List<ProductEntity>> getFavorites() async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      orderBy: 'rowid DESC',
    );
    return rows.map(_mapToProduct).toList(growable: false);
  }

  Future<bool> isFavorite(int productId) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[productId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addFavorite(ProductEntity product) async {
    final Database db = await _database;
    await db.insert(
      _table,
      _productToMap(product),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(int productId) async {
    final Database db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[productId]);
  }

  Future<void> clear() async {
    final Database db = await _database;
    await db.delete(_table);
  }

  Map<String, Object?> _productToMap(ProductEntity product) {
    return <String, Object?>{
      'id': product.id,
      'type_id': product.typeId,
      'name': product.name,
      'description': product.description,
      'image_url': product.imageUrl,
      'price': product.price,
      'available': product.available ? 1 : 0,
    };
  }

  ProductEntity _mapToProduct(Map<String, Object?> row) {
    return ProductEntity(
      id: (row['id'] as num?)?.toInt() ?? 0,
      typeId: (row['type_id'] as num?)?.toInt() ?? 0,
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      imageUrl: (row['image_url'] ?? '').toString(),
      price: ((row['price'] ?? 0) as num).toDouble(),
      available: ((row['available'] ?? 0) as num) != 0,
    );
  }
}
