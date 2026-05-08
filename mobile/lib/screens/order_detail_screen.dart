import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/status_badge.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'receive_payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int? orderId;
  final String? serverOrderId;

  const OrderDetailScreen({super.key, this.orderId, this.serverOrderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  List<Payment> _payments = [];
  Map<String, dynamic>? _measurement;
  bool _loading = true;
  bool _updatingStatus = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppProvider>(context, listen: false).user;
    final role = user?['role'];
    _isAdmin = role == 'Admin' || role?.toString().toLowerCase() == 'admin';
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (!_loading) setState(() => _loading = true);
    Order? order;
    List<Payment> payments = [];
    if (DataService.isOnlineMode && widget.serverOrderId != null) {
      order = await DataService.getOrderByServerId(widget.serverOrderId!);
      if (order != null) {
        final result = await ApiService.get('/payments/by-order/${widget.serverOrderId}');
        if (result['success'] == true && result['data'] is List) {
          payments = (result['data'] as List)
              .map((e) => Payment.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } else if (widget.orderId != null) {
      order = await DataService.getOrderById(widget.orderId!);
      if (order != null) {
        payments = await DataService.getPaymentsByOrder(order.id!);
      }
    }
    // Fetch measurements in online mode
    Map<String, dynamic>? measurement;
    if (DataService.isOnlineMode && order != null && order.customerServerId != null) {
      final mResult = await ApiService.get('/customers/${order.customerServerId}/measurements');
      if (mResult['success'] == true && mResult['data'] is List) {
        final measurements = mResult['data'] as List;
        if (order?.measurementServerId != null) {
          measurement = measurements.cast<Map<String, dynamic>>().where(
              (m) => m['id']?.toString() == order!.measurementServerId).firstOrNull;
        }
        measurement ??= measurements.isNotEmpty
            ? measurements.last as Map<String, dynamic>
            : null;
      }
    }

    if (!mounted) return;
    setState(() {
      _order = order;
      _payments = payments;
      _measurement = measurement;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_order == null || _updatingStatus) return;
    setState(() => _updatingStatus = true);
    final success = await DataService.updateOrderStatus(_order!, newStatus);
    if (!mounted) return;
    setState(() => _updatingStatus = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $newStatus'),
          backgroundColor: AppColors.success,
        ),
      );
      if (!DataService.isOnlineMode) {
        Provider.of<AppProvider>(context, listen: false).syncNow();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    _loadOrder();
  }

  Future<void> _callCustomer() async {
    if (_order?.customerPhone == null) return;
    final uri = Uri.parse('tel:${_order!.customerPhone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp() async {
    if (_order?.customerPhone == null) return;
    final cleaned = Helpers.phoneForWhatsApp(_order!.customerPhone!);
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Detail')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${order.orderType} Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () =>
                Navigator.pushNamed(context, '/invoice', arguments: order.id),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Order',
              onPressed: () => _showEditOrderSheet(context, order),
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Order',
              onPressed: () async {
                final confirm = await _confirmDelete(context, 'this order');
                if (!confirm || !mounted) return;
                final deleted = await DataService.deleteOrder(order);
                if (!mounted) return;
                if (deleted) {
                  if (!DataService.isOnlineMode) {
                    Provider.of<AppProvider>(context, listen: false).syncNow();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order deleted')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete order')),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Design photo
            if (order.designPhotoPath != null &&
                order.designPhotoPath!.isNotEmpty &&
                order.designPhotoPath!.startsWith('http'))
              Image.network(
                order.designPhotoPath!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, size: 60, color: Colors.grey),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer info + status
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          order.customerName?.isNotEmpty == true
                              ? order.customerName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 24,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.customerName ?? 'Unknown',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(order.customerPhone ?? '',
                                style: const TextStyle(
                                    color: AppColors.textMedium)),
                          ],
                        ),
                      ),
                      StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick actions
                  Row(
                    children: [
                      _quickAction(Icons.call, 'Call', AppColors.green, _callCustomer),
                      const SizedBox(width: 8),
                      _quickAction(Icons.chat, 'WhatsApp',
                          const Color(0xFF25D366), _whatsApp),
                      const SizedBox(width: 8),
                      _quickAction(Icons.receipt_long, 'Invoice',
                          AppColors.blue, () {
                        Navigator.pushNamed(context, '/invoice',
                            arguments: order.id);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Amount card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        _amountRow('Stitching', order.stitchingAmount),
                        if (order.materialAmount > 0)
                          _amountRow('Material', order.materialAmount),
                        const Divider(),
                        _amountRow('Total', order.totalAmount, bold: true),
                        _amountRow('Paid', order.paidAmount,
                            color: AppColors.success),
                        _amountRow('Balance', order.balanceAmount,
                            color: order.balanceAmount > 0
                                ? AppColors.error
                                : AppColors.success,
                            bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details
                  if (order.orderNumber != null)
                    _detailRow('Order #', order.orderNumber!),
                  _detailRow('Order Type', order.orderType),
                  if (order.isUrgent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('URGENT',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  _detailRow('Created', Helpers.formatDateTime(order.createdAt)),
                  if (order.dueDate != null) ...[
                    _detailRow('Due Date', Helpers.formatDate(order.dueDate!)),
                    _detailRow('Time Left', Helpers.daysUntil(order.dueDate!)),
                  ],
                  if (order.discount > 0)
                    _detailRow('Discount', Helpers.formatCurrency(order.discount)),
                  if (order.labourAmount > 0)
                    _detailRow('Labour (${order.labourSharePercentage.toStringAsFixed(0)}%)',
                        Helpers.formatCurrency(order.labourAmount)),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _detailRow('Design Notes', order.notes!),
                  if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty)
                    _detailRow('Special Instructions', order.specialInstructions!),

                  // Measurements section
                  if (_measurement != null) ...[
                    const SizedBox(height: 20),
                    const Text('Measurements',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          if (_measurement!['label'] != null)
                            _detailRow('Label', _measurement!['label'].toString()),
                          ..._buildMeasurementRows(),
                          if (_measurement!['notes'] != null && _measurement!['notes'].toString().isNotEmpty)
                            _detailRow('Notes', _measurement!['notes'].toString()),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Status timeline
                  const Text('Status Timeline',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildStatusTimeline(order.status),

                  const SizedBox(height: 20),

                  // Payments
                  Row(
                    children: [
                      const Text('Payments',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (order.balanceAmount > 0)
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReceivePaymentScreen(
                                  preSelectedOrderId: order.id),
                            ),
                          ).then((_) => _loadOrder()),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Payment'),
                        ),
                    ],
                  ),
                  if (_payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No payments yet',
                          style: TextStyle(color: AppColors.textLight)),
                    )
                  else
                    ..._payments.map((p) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments,
                                  color: AppColors.success, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(Helpers.formatCurrency(p.amount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text('${p.method} - ${Helpers.formatDate(p.paidAt)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMedium)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, double amount,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: AppColors.textMedium)),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMedium, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
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

  void _showEditOrderSheet(BuildContext context, Order order) {
    final stitchingCtrl = TextEditingController(
        text: order.stitchingAmount.toStringAsFixed(0));
    final materialCtrl = TextEditingController(
        text: order.materialAmount.toStringAsFixed(0));
    final discountCtrl = TextEditingController(text: '0');
    final dueDateCtrl = TextEditingController(
        text: order.dueDate != null
            ? order.dueDate!.toIso8601String().substring(0, 10)
            : '');
    final notesCtrl = TextEditingController(text: order.notes ?? '');

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
            const Text('Edit Order',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: stitchingCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Stitching Amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: materialCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Material Amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dueDateCtrl,
              decoration: const InputDecoration(
                  labelText: 'Due Date (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes / Design Notes'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final body = <String, dynamic>{
                    'stitchingAmount':
                        double.tryParse(stitchingCtrl.text.trim()) ??
                            order.stitchingAmount,
                    'materialAmount':
                        double.tryParse(materialCtrl.text.trim()) ??
                            order.materialAmount,
                    'discount':
                        double.tryParse(discountCtrl.text.trim()) ?? 0,
                    'notes': notesCtrl.text.trim(),
                  };
                  final due = dueDateCtrl.text.trim();
                  if (due.isNotEmpty) body['dueDate'] = due;

                  if (DataService.isOnlineMode) {
                    await DataService.updateOrder(order, body);
                  } else {
                    if (order.serverId == null || order.serverId!.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order not synced yet.')),
                      );
                      return;
                    }
                    body['id'] = order.serverId;
                    await SyncService.addToQueue(
                      entityType: 'order',
                      entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
                      action: 'update',
                      payload: body,
                    );
                    if (!mounted) return;
                    Provider.of<AppProvider>(context, listen: false).syncNow();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order updated')),
                  );
                  _loadOrder();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMeasurementRows() {
    if (_measurement == null) return [];
    final fields = {
      'length': 'Length / لمبائی',
      'shoulder': 'Shoulder / کندھا',
      'chest': 'Chest / چھاتی',
      'waist': 'Waist / کمر',
      'hip': 'Hip / کولہا',
      'sleeveLength': 'Sleeve Length / آستین',
      'sleeveWidth': 'Sleeve Width',
      'armhole': 'Armhole',
      'neck': 'Neck / گلا',
      'trouserLength': 'Trouser Length',
      'trouserWaist': 'Trouser Waist',
      'inseam': 'Inseam',
      'thighWidth': 'Thigh Width',
      'bottomWidth': 'Bottom Width',
      'damanWidth': 'Daman Width',
      'frontDrop': 'Front Drop',
      'backDrop': 'Back Drop',
    };
    final rows = <Widget>[];
    for (final entry in fields.entries) {
      final val = _measurement![entry.key];
      if (val != null && val.toString() != '0' && val.toString().isNotEmpty) {
        rows.add(_detailRow(entry.value, '${val} inches'));
      }
    }
    return rows;
  }

  Widget _buildStatusTimeline(String currentStatus) {
    return Column(
      children: OrderStatus.all.map((status) {
        final index = OrderStatus.all.indexOf(status);
        final currentIndex = OrderStatus.all.indexOf(currentStatus);
        final isCompleted = index <= currentIndex;
        final isCurrent = status == currentStatus;
        final color = isCompleted
            ? OrderStatus.colorFor(status)
            : AppColors.textLight.withOpacity(0.3);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !isCompleted && index == currentIndex + 1
              ? () => _updateStatus(status)
              : null,
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  if (index < OrderStatus.all.length - 1)
                    Container(
                      width: 2,
                      height: 24,
                      color: color,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
              ),
              if (!isCompleted && index == currentIndex + 1)
                _updatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Tap to update',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
