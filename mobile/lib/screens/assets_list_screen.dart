import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AssetsListScreen extends StatefulWidget {
  const AssetsListScreen({super.key});

  @override
  State<AssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends State<AssetsListScreen> {
  bool _loading = true;
  List<Asset> _assets = [];
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
    final assets = await DataService.getAssets();
    double total = 0;
    for (final a in assets) {
      total += a.totalValue;
    }
    setState(() {
      _assets = assets;
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

  Future<void> _deleteAsset(Asset asset) async {
    if (asset.serverId == null || asset.serverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset not synced yet. Sync first, then delete.')),
      );
      return;
    }
    final confirm = await _confirmDelete(context, asset.name);
    if (!confirm || !mounted) return;
    await SyncService.addToQueue(
      entityType: 'asset',
      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
      action: 'delete',
      payload: {'id': asset.serverId},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queued for deletion')),
    );
    _loadData();
  }

  void _showEditAssetSheet(BuildContext context, Asset asset) {
    final nameCtrl = TextEditingController(text: asset.name);
    final typeCtrl = TextEditingController(text: asset.type);
    final qtyCtrl =
        TextEditingController(text: asset.quantity.toString());
    final valueCtrl =
        TextEditingController(text: asset.unitValue.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: asset.notes ?? '');

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
            const Text('Edit Asset',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: typeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Asset Type')),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Unit Value'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (asset.serverId == null || asset.serverId!.isEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Asset not synced yet. Sync first, then edit.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await SyncService.addToQueue(
                    entityType: 'asset',
                    entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
                    action: 'update',
                    payload: {
                      'id': asset.serverId,
                      'name': nameCtrl.text.trim(),
                      'assetType': typeCtrl.text.trim(),
                      'quantity': int.tryParse(qtyCtrl.text.trim()) ?? asset.quantity,
                      'unitValue': double.tryParse(valueCtrl.text.trim()) ?? asset.unitValue,
                      'notes': notesCtrl.text.trim(),
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

  Future<void> _approveOrReject(Asset asset, bool approve) async {
    if (asset.serverId == null || asset.serverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not synced yet. Sync first, then approve.')),
      );
      return;
    }

    // Update local SQLite immediately
    if (asset.id != null) {
      await DatabaseService.updateAssetStatus(
          asset.id!, approve ? 'Approved' : 'Rejected');
    }
    await SyncService.addToQueue(
      entityType: 'asset',
      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
      action: approve ? 'approve' : 'reject',
      payload: {'id': asset.serverId},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Asset ${approve ? 'approved' : 'rejected'}')),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assets / اثاثے')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: () => Navigator.pushNamed(context, '/add-asset').then((_) => _loadData()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _assets.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.devices, size: 64, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text('No assets yet', style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _assets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildSummary();
                        return _buildAssetCard(_assets[index - 1]);
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
                color: AppColors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.devices, color: AppColors.teal),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_assets.length} Assets', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Total: ${Helpers.formatCurrency(_totalValue)}', style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(Asset asset) {
    final isPending = asset.status == 'Pending';
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
                  backgroundColor: AppColors.teal.withOpacity(0.1),
                  child: const Icon(Icons.devices, color: AppColors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(asset.type, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip('Qty: ${asset.quantity}', AppColors.teal),
                          _chip(Helpers.formatCurrency(asset.totalValue), AppColors.orange),
                          if (asset.owner != null && asset.owner!.isNotEmpty)
                            _chip(asset.owner!, AppColors.purple),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(asset.status),
              ],
            ),
            if (asset.notes != null && asset.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(asset.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPending) ...[
                    _actionBtn('Reject', AppColors.error, Icons.close, () => _approveOrReject(asset, false)),
                    const SizedBox(width: 10),
                    _actionBtn('Approve', AppColors.success, Icons.check, () => _approveOrReject(asset, true)),
                    const SizedBox(width: 10),
                  ],
                  _actionBtn('Edit', AppColors.blue, Icons.edit, () => _showEditAssetSheet(context, asset)),
                  const SizedBox(width: 10),
                  _actionBtn('Delete', AppColors.error, Icons.delete, () => _deleteAsset(asset)),
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
