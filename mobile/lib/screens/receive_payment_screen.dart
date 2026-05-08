import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../widgets/amount_input.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ReceivePaymentScreen extends StatefulWidget {
  final int? preSelectedOrderId;
  const ReceivePaymentScreen({super.key, this.preSelectedOrderId});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  List<Order> _ordersWithBalance = [];
  Order? _selectedOrder;
  final _amountController = TextEditingController();
  String _selectedMethod = PaymentMethods.methods.first;
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await DataService.getOrdersWithBalance();
    Order? preSelected;
    final preId = widget.preSelectedOrderId;
    if (preId != null) {
      // Try in the balance list first; if not there, fetch directly by ID
      preSelected = orders.where((o) => o.id == preId).firstOrNull;
      preSelected ??= await DataService.getOrderById(preId);
      // Ensure it's in the list so it renders
      if (preSelected != null && !orders.any((o) => o.id == preId)) {
        orders.insert(0, preSelected);
      }
    }
    if (!mounted) return;
    setState(() {
      _ordersWithBalance = orders;
      if (preSelected != null) {
        _selectedOrder = preSelected;
        _amountController.text = preSelected.balanceAmount.toStringAsFixed(0);
      }
      _loading = false;
    });
  }

  Future<void> _savePayment() async {
    if (_selectedOrder == null) {
      _showSnack('Please select an order');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnack('Please enter an amount');
      return;
    }
    if (amount > _selectedOrder!.balanceAmount) {
      _showSnack('Amount exceeds balance of ${Helpers.formatCurrency(_selectedOrder!.balanceAmount)}');
      return;
    }

    setState(() => _saving = true);

    try {
      final payment = Payment(
        orderId: _selectedOrder!.id,
        orderServerId: _selectedOrder!.serverId,
        amount: amount,
        method: _selectedMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await DataService.insertPayment(payment);

      if (!mounted) return;
      Provider.of<AppProvider>(context, listen: false).refreshSyncCount();

      _showSuccessDialog(amount);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 50),
              ),
              const SizedBox(height: 20),
              const Text('Payment Received!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('ادائیگی موصول ہوئی',
                  style: TextStyle(color: AppColors.textMedium)),
              const SizedBox(height: 8),
              Text(
                Helpers.formatCurrency(amount),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
              Text('from ${_selectedOrder?.customerName ?? ""}',
                  style: const TextStyle(color: AppColors.textMedium)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ادائیگی وصول کریں',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textMedium)),
                  const SizedBox(height: 20),

                  // Order selection
                  const Text('Select Order',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),

                  if (_ordersWithBalance.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('No orders with pending balance',
                            style: TextStyle(color: AppColors.textMedium)),
                      ),
                    )
                  else
                    ...(_ordersWithBalance.map((order) {
                      final isSelected = DataService.isOnlineMode
                          ? _selectedOrder?.serverId == order.serverId
                          : _selectedOrder?.id == order.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOrder = order;
                            _amountController.text =
                                order.balanceAmount.toStringAsFixed(0);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: AppColors.primary, size: 22)
                              else
                                Icon(Icons.circle_outlined,
                                    color: Colors.grey.shade400, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${order.customerName} - ${order.orderType}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    Text(
                                      'Balance: ${Helpers.formatCurrency(order.balanceAmount)}',
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })),

                  const SizedBox(height: 20),

                  // Amount
                  AmountInput(
                    label: 'Amount / رقم',
                    controller: _amountController,
                  ),
                  const SizedBox(height: 16),

                  // Payment method
                  const Text('Payment Method',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: PaymentMethods.methods.map((method) {
                      final isSelected = _selectedMethod == method;
                      return ChoiceChip(
                        label: Text(method),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        onSelected: (_) =>
                            setState(() => _selectedMethod = method),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                      labelText: 'Notes',
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _savePayment,
                      icon: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.payments),
                      label: Text(_saving ? 'Saving...' : 'Receive Payment',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
