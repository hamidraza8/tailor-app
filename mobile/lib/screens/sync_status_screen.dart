import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_item.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  List<SyncItem> _items = [];
  bool _loading = true;
  bool _resyncing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.getAllSyncItems();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _retrySync() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.syncNow(forceRetry: true);
    _loadItems();
  }

  Future<void> _clearCompleted() async {
    for (final item in _items.where((i) => i.status == 'completed')) {
      await DatabaseService.removeSyncItem(item.id!);
    }
    _loadItems();
  }

  Future<void> _clearAll() async {
    for (final item in _items) {
      await DatabaseService.removeSyncItem(item.id!);
    }
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.refreshSyncCount();
    _loadItems();
  }

  Future<void> _resyncAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-sync All from Server?'),
        content: const Text(
            'This will fetch all server records and update your local data. '
            'Pending unsynced changes will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-sync')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _resyncing = true);
    final result = await SyncService.resyncAll();
    if (!mounted) return;
    setState(() => _resyncing = false);

    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.refreshSyncCount();

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Re-synced: ${result['orders']} orders, ${result['customers']} customers, '
            '${result['payments']} payments, ${result['assets']} assets, '
            '${result['inventory']} inventory'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Re-sync failed'),
        backgroundColor: AppColors.error,
      ));
    }
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        actions: [
          if (_resyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_download),
              onPressed: _resyncAll,
              tooltip: 'Re-sync all from server',
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearCompleted,
            tooltip: 'Clear completed',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All?'),
                  content: const Text('Remove all sync queue items including failed ones?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All')),
                  ],
                ),
              );
              if (confirm == true) _clearAll();
            },
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary
                Consumer<AppProvider>(
                  builder: (context, provider, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: provider.isOnline
                          ? AppColors.success.withOpacity(0.05)
                          : AppColors.warning.withOpacity(0.05),
                      child: Row(
                        children: [
                          Icon(
                            provider.isOnline
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: provider.isOnline
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.isOnline
                                      ? 'Online'
                                      : 'Offline',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  '${provider.pendingSyncCount} items pending',
                                  style: const TextStyle(
                                      color: AppColors.textMedium,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: provider.isSyncing ? null : _retrySync,
                            icon: provider.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: Text(
                                provider.isSyncing ? 'Syncing' : 'Sync Now'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Items list
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_done,
                                  size: 64,
                                  color: AppColors.success.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text('All synced!',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textMedium)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadItems,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            itemBuilder: (context, index) =>
                                _buildSyncItemCard(_items[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSyncItemCard(SyncItem item) {
    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = AppColors.error;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppColors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          '${item.action.toUpperCase()} ${item.entityType}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${item.entityId} | ${Helpers.timeAgo(item.createdAt)}',
                style: const TextStyle(fontSize: 12)),
            if (item.errorMessage != null)
              Text(item.errorMessage!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 11)),
            if (item.retryCount > 0)
              Text('Retries: ${item.retryCount}',
                  style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(item.status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
