import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Service for persistent file-based storage of orders.
/// This service saves orders as individual JSON files and provides
/// backup/export functionality for offline access.
class OrdersFileStorage {
  OrdersFileStorage._();
  static final OrdersFileStorage instance = OrdersFileStorage._();

  static const String _ordersFolder = 'orders';
  static const String _ordersListFile = 'orders_list.json';
  static const String _orderDetailsPrefix = 'order_';
  static const String _backupFolder = 'backups';
  static const String _exportFolder = 'exports';

  /// Get the orders directory path
  Future<Directory> _getOrdersDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory ordersDir = Directory('${appDir.path}/$_ordersFolder');
    if (!await ordersDir.exists()) {
      await ordersDir.create(recursive: true);
    }
    return ordersDir;
  }

  /// Get the backups directory path
  Future<Directory> _getBackupsDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory backupsDir = Directory('${appDir.path}/$_ordersFolder/$_backupFolder');
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Get the exports directory path
  Future<Directory> _getExportsDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory exportsDir = Directory('${appDir.path}/$_ordersFolder/$_exportFolder');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  /// Save the complete orders list to a file
  Future<bool> saveOrdersList(List<Map<String, dynamic>> orders) async {
    try {
      final Directory dir = await _getOrdersDirectory();
      final File file = File('${dir.path}/$_ordersListFile');

      final Map<String, dynamic> data = {
        'timestamp': DateTime.now().toIso8601String(),
        'count': orders.length,
        'orders': orders,
      };

      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      print('Error saving orders list to file: $e');
      return false;
    }
  }

  /// Read the complete orders list from file
  Future<List<Map<String, dynamic>>> readOrdersList() async {
    try {
      final Directory dir = await _getOrdersDirectory();
      final File file = File('${dir.path}/$_ordersListFile');

      if (!await file.exists()) {
        return <Map<String, dynamic>>[];
      }

      final String content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      final List<dynamic> orders = data['orders'] as List<dynamic>;

      return orders.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading orders list from file: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Save an individual order details to a separate file
  Future<bool> saveOrderDetails(int orderId, Map<String, dynamic> orderDetails) async {
    try {
      final Directory dir = await _getOrdersDirectory();
      final File file = File('${dir.path}/$_orderDetailsPrefix$orderId.json');

      final Map<String, dynamic> data = {
        'timestamp': DateTime.now().toIso8601String(),
        'orderId': orderId,
        'details': orderDetails,
      };

      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      print('Error saving order details to file: $e');
      return false;
    }
  }

  /// Read an individual order details from file
  Future<Map<String, dynamic>?> readOrderDetails(int orderId) async {
    try {
      final Directory dir = await _getOrdersDirectory();
      final File file = File('${dir.path}/$_orderDetailsPrefix$orderId.json');

      if (!await file.exists()) {
        return null;
      }

      final String content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;

      return data['details'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error reading order details from file: $e');
      return null;
    }
  }

  /// Delete an individual order file
  Future<bool> deleteOrderDetails(int orderId) async {
    try {
      final Directory dir = await _getOrdersDirectory();
      final File file = File('${dir.path}/$_orderDetailsPrefix$orderId.json');

      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting order details file: $e');
      return false;
    }
  }

  /// Create a backup of all orders
  Future<String?> createBackup() async {
    try {
      final Directory backupsDir = await _getBackupsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File backupFile = File('${backupsDir.path}/orders_backup_$timestamp.json');

      final List<Map<String, dynamic>> ordersList = await readOrdersList();
      final Directory ordersDir = await _getOrdersDirectory();

      // Gather all order details files
      final Map<String, dynamic> backup = {
        'timestamp': DateTime.now().toIso8601String(),
        'ordersList': ordersList,
        'orderDetails': <String, dynamic>{},
      };

      // Read all individual order files
      final List<FileSystemEntity> files = ordersDir.listSync();
      for (final FileSystemEntity entity in files) {
        if (entity is File && entity.path.contains(_orderDetailsPrefix)) {
          final String filename = entity.path.split(Platform.pathSeparator).last;
          final String content = await entity.readAsString();
          backup['orderDetails'][filename] = jsonDecode(content);
        }
      }

      await backupFile.writeAsString(jsonEncode(backup));
      return backupFile.path;
    } catch (e) {
      print('Error creating backup: $e');
      return null;
    }
  }

  /// Restore from a backup file
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final File backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return false;
      }

      final String content = await backupFile.readAsString();
      final Map<String, dynamic> backup = jsonDecode(content) as Map<String, dynamic>;

      // Restore orders list
      final List<dynamic> ordersList = backup['ordersList'] as List<dynamic>;
      await saveOrdersList(ordersList.cast<Map<String, dynamic>>());

      // Restore individual order details
      final Map<String, dynamic> orderDetails = backup['orderDetails'] as Map<String, dynamic>;
      final Directory ordersDir = await _getOrdersDirectory();

      for (final String filename in orderDetails.keys) {
        final File file = File('${ordersDir.path}/$filename');
        await file.writeAsString(jsonEncode(orderDetails[filename]));
      }

      return true;
    } catch (e) {
      print('Error restoring from backup: $e');
      return false;
    }
  }

  /// List all available backups
  Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final Directory backupsDir = await _getBackupsDirectory();
      final List<FileSystemEntity> files = backupsDir.listSync();
      final List<Map<String, dynamic>> backups = [];

      for (final FileSystemEntity entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final String filename = entity.path.split(Platform.pathSeparator).last;
          final FileStat stat = await entity.stat();

          backups.add({
            'filename': filename,
            'path': entity.path,
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          });
        }
      }

      // Sort by modified date (newest first)
      backups.sort((a, b) =>
        DateTime.parse(b['modified'] as String).compareTo(
          DateTime.parse(a['modified'] as String)
        )
      );

      return backups;
    } catch (e) {
      print('Error listing backups: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Export orders to a human-readable format
  Future<String?> exportOrdersToJson() async {
    try {
      final Directory exportsDir = await _getExportsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File exportFile = File('${exportsDir.path}/orders_export_$timestamp.json');

      final List<Map<String, dynamic>> ordersList = await readOrdersList();

      final Map<String, dynamic> export = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalOrders': ordersList.length,
        'orders': ordersList,
      };

      // Pretty print JSON for readability
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(export);

      await exportFile.writeAsString(prettyJson);
      return exportFile.path;
    } catch (e) {
      print('Error exporting orders: $e');
      return null;
    }
  }

  /// Clear all order files (use with caution!)
  Future<bool> clearAllOrders() async {
    try {
      final Directory dir = await _getOrdersDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      print('Error clearing all orders: $e');
      return false;
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final Directory ordersDir = await _getOrdersDirectory();
      final Directory backupsDir = await _getBackupsDirectory();
      final Directory exportsDir = await _getExportsDirectory();

      int ordersCount = 0;
      int ordersSize = 0;
      int backupsCount = 0;
      int backupsSize = 0;
      int exportsCount = 0;
      int exportsSize = 0;

      // Count orders files
      if (await ordersDir.exists()) {
        final List<FileSystemEntity> files = ordersDir.listSync();
        for (final FileSystemEntity entity in files) {
          if (entity is File) {
            ordersCount++;
            final FileStat stat = await entity.stat();
            ordersSize += stat.size;
          }
        }
      }

      // Count backup files
      if (await backupsDir.exists()) {
        final List<FileSystemEntity> files = backupsDir.listSync();
        for (final FileSystemEntity entity in files) {
          if (entity is File) {
            backupsCount++;
            final FileStat stat = await entity.stat();
            backupsSize += stat.size;
          }
        }
      }

      // Count export files
      if (await exportsDir.exists()) {
        final List<FileSystemEntity> files = exportsDir.listSync();
        for (final FileSystemEntity entity in files) {
          if (entity is File) {
            exportsCount++;
            final FileStat stat = await entity.stat();
            exportsSize += stat.size;
          }
        }
      }

      return {
        'orders': {
          'count': ordersCount,
          'sizeBytes': ordersSize,
          'sizeMB': (ordersSize / (1024 * 1024)).toStringAsFixed(2),
        },
        'backups': {
          'count': backupsCount,
          'sizeBytes': backupsSize,
          'sizeMB': (backupsSize / (1024 * 1024)).toStringAsFixed(2),
        },
        'exports': {
          'count': exportsCount,
          'sizeBytes': exportsSize,
          'sizeMB': (exportsSize / (1024 * 1024)).toStringAsFixed(2),
        },
        'total': {
          'sizeBytes': ordersSize + backupsSize + exportsSize,
          'sizeMB': ((ordersSize + backupsSize + exportsSize) / (1024 * 1024)).toStringAsFixed(2),
        },
      };
    } catch (e) {
      print('Error getting storage stats: $e');
      return <String, dynamic>{};
    }
  }

  /// Delete old backups (keep only the most recent N backups)
  Future<int> cleanOldBackups({int keepCount = 5}) async {
    try {
      final List<Map<String, dynamic>> backups = await listBackups();

      if (backups.length <= keepCount) {
        return 0;
      }

      int deletedCount = 0;
      for (int i = keepCount; i < backups.length; i++) {
        final String path = backups[i]['path'] as String;
        final File file = File(path);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      print('Error cleaning old backups: $e');
      return 0;
    }
  }
}

