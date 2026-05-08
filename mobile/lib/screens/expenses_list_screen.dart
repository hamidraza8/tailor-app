import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _spendings = [];
  double _totalAmount = 0;
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

    final spendings = await DataService.getSpendings();

    double total = 0;
    for (final s in spendings) {
      total += (s['totalAmount'] as num?)?.toDouble() ?? 0;
    }
    setState(() {
      _spendings = spendings;
      _totalAmount = total;
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

  Future<void> _deleteSpending(Map<String, dynamic> s) async {
    final id = s['id']?.toString() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not synced yet. Sync first, then delete.')),
      );
      return;
    }
    final confirm = await _confirmDelete(context, 'this spending');
    if (!confirm || !mounted) return;
    await SyncService.addToQueue(
      entityType: 'spending',
      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
      action: 'delete',
      payload: {'id': id},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queued for deletion')),
    );
    _loadData();
  }

  Future<void> _approveOrReject(Map<String, dynamic> s, bool approve) async {
    final id = s['id']?.toString() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not synced yet. Sync first, then approve.')),
      );
      return;
    }

    await SyncService.addToQueue(
      entityType: 'spending',
      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
      action: approve ? 'approve' : 'reject',
      payload: {'id': id},
    );
    if (!mounted) return;
    Provider.of<AppProvider>(context, listen: false).syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Spending ${approve ? 'approved' : 'rejected'} — syncing')),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses / اخراجات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        onPressed: () => Navigator.pushNamed(context, '/add-spending').then((_) => _loadData()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _spendings.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text('No expenses yet', style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _spendings.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildSummary();
                        return _buildExpenseCard(_spendings[index - 1]);
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
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.red),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_spendings.length} Expenses', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Total: ${Helpers.formatCurrency(_totalAmount)}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> s) {
    final status = s['approvalStatus']?.toString() ?? 'PendingApproval';
    final isPending = status == 'Pending' || status == 'PendingApproval';
    final category = s['category']?.toString() ?? '';
    final amount = (s['totalAmount'] as num?)?.toDouble() ?? 0;
    final description = s['description']?.toString() ?? '';
    final spendingNo = s['spendingNo']?.toString() ?? '';
    final spendingDate = s['spendingDate'] != null
        ? DateTime.tryParse(s['spendingDate'].toString()) ?? DateTime.now()
        : DateTime.now();

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
                  backgroundColor: AppColors.red.withOpacity(0.1),
                  child: Text(
                    category.isNotEmpty ? category.substring(0, 1) : 'E',
                    style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(Helpers.formatCurrency(amount), AppColors.red),
                          const SizedBox(width: 8),
                          _chip(Helpers.formatDate(spendingDate), AppColors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (spendingNo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(spendingNo, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPending) ...[
                    _actionBtn('Reject', AppColors.error, Icons.close, () => _approveOrReject(s, false)),
                    const SizedBox(width: 10),
                    _actionBtn('Approve', AppColors.success, Icons.check, () => _approveOrReject(s, true)),
                    const SizedBox(width: 10),
                  ],
                  _actionBtn('Delete', AppColors.error, Icons.delete, () => _deleteSpending(s)),
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
    final color = status == 'Approved' ? AppColors.success : (status == 'Rejected') ? AppColors.error : AppColors.warning;
    final label = status == 'PendingApproval' ? 'Pending' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
