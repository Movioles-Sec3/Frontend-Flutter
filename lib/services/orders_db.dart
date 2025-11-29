import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class OrdersDb {
  OrdersDb._();
  static final OrdersDb instance = OrdersDb._();

  static const String _dbName = 'orders.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final String path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        order_number TEXT,
        total REAL NOT NULL,
        status TEXT NOT NULL,
        placed_at TEXT,
        ready_at TEXT,
        delivered_at TEXT
      );
    ''' );

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''' );

    // Indexes for faster lookups
    await db.execute('CREATE INDEX idx_order_items_order_id ON order_items(order_id);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No-op for now; add migrations as versions increase
  }

  Future<void> upsertOrder({
    required int id,
    String? orderNumber,
    required double total,
    required String status,
    String? placedAt,
    String? readyAt,
    String? deliveredAt,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'orders',
        <String, Object?>{
          'id': id,
          'order_number': orderNumber,
          'total': total,
          'status': status,
          'placed_at': placedAt,
          'ready_at': readyAt,
          'delivered_at': deliveredAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Replace items for this order
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: <Object?>[id]);
      for (final Map<String, dynamic> item in items) {
        await txn.insert('order_items', <String, Object?>{
          'order_id': id,
          'product_id': (item['productId'] ?? item['id_producto'] ?? 0) as int,
          'name': (item['name'] ?? item['nombre'] ?? '').toString(),
          'quantity': (item['quantity'] ?? item['cantidad'] ?? 0) as int,
          'unit_price': ((item['unitPrice'] ?? item['precio'] ?? 0) as num).toDouble(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'orders',
      orderBy: 'placed_at DESC, id DESC',
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: <Object?>[orderId],
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getOrderItemsByProduct(
    int productId,
  ) async {
    final db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'order_items',
      columns: <String>['quantity'],
      where: 'product_id = ?',
      whereArgs: <Object?>[productId],
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<void> updateOrderStatus({
    required int id,
    required String status,
    String? readyAt,
    String? deliveredAt,
  }) async {
    final db = await database;
    await db.update(
      'orders',
      <String, Object?>{
        'status': status,
        if (readyAt != null) 'ready_at': readyAt,
        if (deliveredAt != null) 'delivered_at': deliveredAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}

