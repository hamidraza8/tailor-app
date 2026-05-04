import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  bool _loading = true;
  List<InventoryTransaction> _items = [];
  double _totalValue = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppProvider>(context, listen: false).user;
    final role = user?['role'];
    _isAdmin = role == 0 || role == 'Admin' || role?.toString().toLowerCase() == 'admin';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final items = await DatabaseService.getInventoryTransactions();
    double total = 0;
    for (final i in items) {
      total += i.totalCost;
    }
    setState(() {
      _items = items;
      _totalValue = total;
      _loading = false;
    });
  }

  Future<bool> _confirmDelete(BuildContext context, String item) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete $item?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteItem(InventoryTransaction item) async {
    if (item.serverId == null || item.serverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not synced yet. Sync first, then delete.')),
      );
      return;
    }
    final confirm = await _confirmDelete(context, item.itemName);
    if (!confirm || !mounted) return;
    await DatabaseService.deleteInventoryTransaction(item.id!);
    await SyncService.addToQueue(
      entityType: 'inventory',
      entityId: item.id!,
      action: 'delete',
      payload: {'id': item.serverId},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted')),
    );
    _loadData();
  }

  void _showEditItemSheet(BuildContext context, InventoryTransaction item) {
    final nameCtrl = TextEditingController(text: item.itemName);
    final unitCtrl = TextEditingController(text: item.unit ?? '');
    final costCtrl =
        TextEditingController(text: item.costPerUnit.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Inventory Item',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Unit')),
            const SizedBox(height: 8),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Unit Cost'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (item.serverId == null || item.serverId!.isEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Item not synced yet. Sync first, then edit.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await SyncService.addToQueue(
                    entityType: 'inventory',
                    entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
                    action: 'update',
                    payload: {
                      'id': item.serverId,
                      'itemName': nameCtrl.text.trim(),
                      'unit': unitCtrl.text.trim(),
                      'costPerUnit': double.tryParse(costCtrl.text.trim()) ?? item.costPerUnit,
                    },
                  );
                  if (!mounted) return;
                  Provider.of<AppProvider>(context, listen: false).syncNow();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved — syncing')),
                  );
                  _loadData();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveOrReject(InventoryTransaction item, bool approve) async {
    if (item.serverId == null || item.serverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not synced yet. Sync first, then approve.')),
      );
      return;
    }

    // Update local SQLite immediately
    if (item.id != null) {
      await DatabaseService.updateInventoryStatus(
          item.id!, approve ? 'Approved' : 'Rejected');
    }
    await SyncService.addToQueue(
      entityType: 'inventory',
      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
      action: approve ? 'approve' : 'reject',
      payload: {'id': item.serverId},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item ${approve ? 'approved' : 'rejected'}')),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory / سامان')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.purple,
        onPressed: () => Navigator.pushNamed(context, '/add-inventory').then((_) => _loadData()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _items.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2, size: 64, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text('No inventory yet', style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildSummary();
                        return _buildItemCard(_items[index - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2, color: AppColors.purple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_items.length} Items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Total: ${Helpers.formatCurrency(_totalValue)}', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryTransaction item) {
    final isPending = item.status == 'Pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.purple.withOpacity(0.1),
                  child: const Icon(Icons.inventory_2, color: AppColors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip('${item.quantity} ${item.unit ?? 'pcs'}', AppColors.purple),
                          _chip('${Helpers.formatCurrency(item.costPerUnit)}/unit', AppColors.blue),
                          _chip(Helpers.formatCurrency(item.totalCost), AppColors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(item.status),
              ],
            ),
            if (item.supplier != null && item.supplier!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Supplier: ${item.supplier}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ],
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(item.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPending) ...[
                    _actionBtn('Reject', AppColors.error, Icons.close, () => _approveOrReject(item, false)),
                    const SizedBox(width: 10),
                    _actionBtn('Approve', AppColors.success, Icons.check, () => _approveOrReject(item, true)),
                    const SizedBox(width: 10),
                  ],
                  _actionBtn('Edit', AppColors.blue, Icons.edit, () => _showEditItemSheet(context, item)),
                  const SizedBox(width: 10),
                  _actionBtn('Delete', AppColors.error, Icons.delete, () => _deleteItem(item)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'Approved' ? AppColors.success : status == 'Rejected' ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
