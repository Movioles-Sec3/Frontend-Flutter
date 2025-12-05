import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/orders_file_storage.dart';

/// Page for managing orders file storage, backups, and exports
class OrdersStorageManagerPage extends StatefulWidget {
  const OrdersStorageManagerPage({super.key});

  @override
  State<OrdersStorageManagerPage> createState() => _OrdersStorageManagerPageState();
}

class _OrdersStorageManagerPageState extends State<OrdersStorageManagerPage> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      final stats = await OrdersFileStorage.instance.getStorageStats();
      final backups = await OrdersFileStorage.instance.listBackups();

      setState(() {
        _stats = stats;
        _backups = backups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading storage data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    try {
      setState(() {
        _loading = true;
      });

      final path = await OrdersFileStorage.instance.createBackup();

      setState(() {
        _loading = false;
      });

      if (path != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create backup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace your current orders data with the backup. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _loading = true;
      });

      final success = await OrdersFileStorage.instance.restoreFromBackup(path);

      setState(() {
        _loading = false;
      });

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to restore backup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportOrders() async {
    try {
      setState(() {
        _loading = true;
      });

      final path = await OrdersFileStorage.instance.exportOrdersToJson();

      setState(() {
        _loading = false;
      });

      if (path != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Orders exported to:\n${path.split('/').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to export orders'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cleanOldBackups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Old Backups'),
        content: const Text(
          'This will keep only the 5 most recent backups and delete the rest. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _loading = true;
      });

      final deletedCount = await OrdersFileStorage.instance.cleanOldBackups(keepCount: 5);

      setState(() {
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount old backup(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cleaning backups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Storage Manager'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Storage Statistics Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Storage Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (_stats != null) ...[
                            _buildStatRow(
                              'Orders Files',
                              '${_stats!['orders']['count']} files (${_stats!['orders']['sizeMB']} MB)',
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Backups',
                              '${_stats!['backups']['count']} files (${_stats!['backups']['sizeMB']} MB)',
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Exports',
                              '${_stats!['exports']['count']} files (${_stats!['exports']['sizeMB']} MB)',
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Total Size',
                              '${_stats!['total']['sizeMB']} MB',
                              isBold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Actions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildActionButton(
                            icon: Icons.backup,
                            label: 'Create Backup',
                            onPressed: _createBackup,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            icon: Icons.file_download,
                            label: 'Export Orders (JSON)',
                            onPressed: _exportOrders,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            icon: Icons.cleaning_services,
                            label: 'Clean Old Backups',
                            onPressed: _cleanOldBackups,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Backups List Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Available Backups',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (_backups.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No backups available'),
                              ),
                            )
                          else
                            ..._backups.map((backup) => _buildBackupTile(backup)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBackupTile(Map<String, dynamic> backup) {
    final filename = backup['filename'] as String;
    final size = _formatFileSize(backup['size'] as int);
    final modified = _formatDate(backup['modified'] as String);
    final path = backup['path'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.folder_zip, color: Colors.blue),
        title: Text(
          filename,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '$modified • $size',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.restore),
          onPressed: () => _restoreBackup(path),
          tooltip: 'Restore this backup',
        ),
      ),
    );
  }
}

