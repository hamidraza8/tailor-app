import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  bool _loading = true;
  List<Payment> _payments = [];
  double _totalAmount = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppProvider>(context, listen: false).user;
    final role = user?['role'];
    _isAdmin = role == 'Admin' || role?.toString().toLowerCase() == 'admin';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final payments = await DatabaseService.getAllPayments();
    double total = 0;
    for (final p in payments) {
      total += p.amount;
    }
    setState(() {
      _payments = payments;
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

  Future<void> _deletePayment(Payment payment) async {
    final confirm = await _confirmDelete(context, 'this payment');
    if (!confirm || !mounted) return;
    await DatabaseService.deletePayment(payment);
    // Only queue server delete if it was already synced
    if (payment.serverId != null && payment.serverId!.isNotEmpty) {
      await SyncService.addToQueue(
        entityType: 'payment',
        entityId: payment.id!,
        action: 'delete',
        payload: {'id': payment.serverId},
      );
      if (!mounted) return;
      Provider.of<AppProvider>(context, listen: false).syncNow();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment deleted')),
    );
    _loadData();
  }

  IconData _methodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'jazzcash':
      case 'easypaisa':
        return Icons.phone_android;
      case 'bank transfer':
        return Icons.account_balance;
      default:
        return Icons.payments;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments / ادائیگیاں')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        onPressed: () => Navigator.pushNamed(context, '/receive-payment').then((_) => _loadData()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _payments.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments, size: 64, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text('No payments yet', style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildSummary();
                        return _buildPaymentCard(_payments[index - 1]);
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
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments, color: AppColors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_payments.length} Payments', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Total: ${Helpers.formatCurrency(_totalAmount)}', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.orange.withOpacity(0.1),
              child: Icon(_methodIcon(payment.method), color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Helpers.formatCurrency(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(payment.method, AppColors.orange),
                      const SizedBox(width: 8),
                      _chip(Helpers.formatDate(payment.paidAt), AppColors.blue),
                    ],
                  ),
                  if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(payment.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ],
              ),
            ),
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                tooltip: 'Delete',
                onPressed: () => _deletePayment(payment),
              ),
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
}
