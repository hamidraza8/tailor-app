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
    final statusColor = OrderStatus.colorFor(order.status);
    final isOverdue = order.dueDate != null && order.dueDate!.isBefore(DateTime.now())
        && order.status != OrderStatus.delivered;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/order-detail',
            arguments: DataService.isOnlineMode ? order.serverId : order.id),
        child: Column(
          children: [
            // Status accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  // Top row: avatar, name, status
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            order.customerName?.isNotEmpty == true
                                ? order.customerName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
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
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.checkroom, size: 13, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Text(order.orderType,
                                    style: const TextStyle(
                                        color: AppColors.textMedium, fontSize: 12)),
                                if (order.orderNumber != null) ...[
                                  const SizedBox(width: 8),
                                  Text(order.orderNumber!,
                                      style: TextStyle(
                                          color: AppColors.textLight, fontSize: 11)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: order.status),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Amount summary row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _amountColumn('Total', order.totalAmount, AppColors.textDark),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _amountColumn('Paid', order.paidAmount, AppColors.success),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _amountColumn('Due', order.balanceAmount,
                            hasBalance ? AppColors.error : AppColors.success),
                      ],
                    ),
                  ),

                  // Due date & urgency
                  if (order.dueDate != null || order.isUrgent) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (order.isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, size: 12, color: AppColors.error),
                                const SizedBox(width: 2),
                                Text('Urgent', style: TextStyle(
                                    color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (order.dueDate != null) ...[
                          Icon(Icons.schedule, size: 13,
                              color: isOverdue ? AppColors.error : AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            '${Helpers.formatDate(order.dueDate!)} (${Helpers.daysUntil(order.dueDate!)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOverdue ? AppColors.error : AppColors.textMedium,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Action row — icon buttons only
                  Row(
                    children: [
                      if (order.customerPhone != null &&
                          order.customerPhone!.isNotEmpty) ...[
                        _iconAction(Icons.call, AppColors.green,
                            () => _callCustomer(order.customerPhone!)),
                        const SizedBox(width: 6),
                        _iconAction(Icons.chat_bubble, const Color(0xFF25D366),
                            () => _whatsAppCustomer(order.customerPhone!)),
                        const SizedBox(width: 6),
                      ],
                      if (order.status != OrderStatus.ready &&
                          order.status != OrderStatus.delivered)
                        _pillAction(Icons.check, 'Mark Ready', AppColors.success,
                            () => _markReady(order)),
                      if (hasBalance) ...[
                        const SizedBox(width: 6),
                        _pillAction(Icons.payments, 'Pay', AppColors.orange, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReceivePaymentScreen(
                                  preSelectedOrderId: order.id),
                            ),
                          ).then((_) => _loadOrders());
                        }),
                      ],
                      const Spacer(),
                      if (_isAdmin)
                        _iconAction(Icons.delete_outline, AppColors.error.withOpacity(0.6),
                            () => _deleteOrder(order)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountColumn(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(
              fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  Widget _pillAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
