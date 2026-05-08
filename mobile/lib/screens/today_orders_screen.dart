import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/status_badge.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'receive_payment_screen.dart';

class TodayOrdersScreen extends StatefulWidget {
  const TodayOrdersScreen({super.key});

  @override
  State<TodayOrdersScreen> createState() => _TodayOrdersScreenState();
}

class _TodayOrdersScreenState extends State<TodayOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _todayOrders = [];
  List<Order> _activeOrders = [];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = Provider.of<AppProvider>(context, listen: false).user;
    final role = user?['role'];
    _isAdmin = role == 'Admin' || role?.toString().toLowerCase() == 'admin';
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final today = await DataService.getTodayOrders();
    final active = await DataService.getActiveOrders();
    setState(() {
      _todayOrders = today;
      _activeOrders = active;
      _loading = false;
    });
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsAppCustomer(String phone) async {
    final cleaned = Helpers.phoneForWhatsApp(phone);
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Future<void> _deleteOrder(Order order) async {
    final confirm =
        await _confirmDelete(context, '${order.customerName ?? 'this'} order');
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
      _loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete order')),
      );
    }
  }

  Future<void> _markReady(Order order) async {
    await DataService.updateOrderStatus(order, OrderStatus.ready);
    if (!DataService.isOnlineMode && mounted) {
      Provider.of<AppProvider>(context, listen: false).syncNow();
    }
    _loadOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.customerName} order marked as Ready!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Orders"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: "Today (${_todayOrders.length})"),
            Tab(text: "All Active (${_activeOrders.length})"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_todayOrders, emptyMessage: 'No orders today'),
                _buildOrderList(_activeOrders,
                    emptyMessage: 'No active orders'),
              ],
            ),
    );
  }

  Widget _buildOrderList(List<Order> orders, {required String emptyMessage}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: AppColors.textLight.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textMedium)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) => _buildOrderCard(orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final hasBalance = order.balanceAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/order-detail',
            arguments: DataService.isOnlineMode ? order.serverId : order.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      order.customerName?.isNotEmpty == true
                          ? order.customerName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          order.orderType,
                          style: const TextStyle(
                              color: AppColors.textMedium, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),

              const SizedBox(height: 12),

              // Amount row
              Row(
                children: [
                  _infoChip(Icons.payments, Helpers.formatCurrency(order.totalAmount),
                      AppColors.primary),
                  const SizedBox(width: 8),
                  if (hasBalance)
                    _infoChip(
                      Icons.warning,
                      'Due: ${Helpers.formatCurrency(order.balanceAmount)}',
                      AppColors.error,
                    ),
                  const Spacer(),
                  if (order.dueDate != null)
                    Text(
                      Helpers.daysUntil(order.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: order.dueDate!.isBefore(DateTime.now())
                            ? AppColors.error
                            : AppColors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty) ...[
                    _actionButton(
                      Icons.call,
                      'Call',
                      AppColors.green,
                      () => _callCustomer(order.customerPhone!),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      Icons.chat,
                      'WhatsApp',
                      const Color(0xFF25D366),
                      () => _whatsAppCustomer(order.customerPhone!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (order.status != OrderStatus.ready &&
                      order.status != OrderStatus.delivered)
                    _actionButton(
                      Icons.check_circle_outline,
                      'Ready',
                      AppColors.success,
                      () => _markReady(order),
                    ),
                  if (hasBalance) ...[
                    const SizedBox(width: 8),
                    _actionButton(
                      Icons.payments,
                      'Payment',
                      AppColors.orange,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceivePaymentScreen(
                              preSelectedOrderId: order.id),
                        ),
                      ).then((_) => _loadOrders()),
                    ),
                  ],
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    _actionButton(
                      Icons.delete,
                      'Delete',
                      AppColors.error,
                      () => _deleteOrder(order),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
