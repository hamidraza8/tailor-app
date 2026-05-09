import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/premium_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/sync_indicator.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/inventory.dart';
import '../models/asset.dart';
import '../services/data_service.dart';
import 'package:intl/intl.dart';
import 'partner_balances_screen.dart';
import 'add_capital_screen.dart';
import 'add_spending_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  double _totalRevenue = 0;
  double _totalCollected = 0;
  int _activeOrderCount = 0;
  int _todayOrderCount = 0;
  int _overdueCount = 0;
  int _dueSoonCount = 0;
  int _onTrackCount = 0;
  int _unpaidOrderCount = 0;
  double _unpaidBalance = 0;
  int _pendingExpenseCount = 0;
  int _pendingInventoryCount = 0;
  double _totalExpenses = 0;
  double _collectionRate = 0;
  double _estimatedProfit = 0;
  double _totalInventoryValue = 0;
  int _inventoryItemCount = 0;
  double _totalAssetValue = 0;
  int _assetCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      DataService.getOrders(),
      DataService.getActiveOrders(),
      DataService.getTodayOrders(),
      DataService.getOrdersWithBalance(),
      DataService.getAllPayments(),
      DataService.getSpendings(),
      DataService.getInventoryTransactions(),
      DataService.getAssets(),
    ]);

    final allOrders = results[0] as List<Order>;
    final activeOrders = results[1] as List<Order>;
    final todayOrders = results[2] as List<Order>;
    final unpaidOrders = results[3] as List<Order>;
    final payments = results[4] as List<Payment>;
    final spendingsRaw = results[5] as List<Map<String, dynamic>>;
    final inventory = results[6] as List<InventoryTransaction>;
    final assets = results[7] as List<Asset>;

    double revenue = 0;
    for (final o in allOrders) revenue += o.totalAmount;
    double collected = 0;
    for (final p in payments) collected += p.amount;
    double unpaidBal = 0;
    for (final o in unpaidOrders) unpaidBal += o.balanceAmount;

    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    int overdue = 0, dueSoon = 0, onTrack = 0;
    for (final o in activeOrders) {
      if (o.dueDate != null) {
        if (o.dueDate!.isBefore(now)) overdue++;
        else if (o.dueDate!.isBefore(weekFromNow)) dueSoon++;
        else onTrack++;
      } else {
        onTrack++;
      }
    }

    double totalExp = 0;
    int pendingExp = 0;
    for (final s in spendingsRaw) {
      totalExp += (s['totalAmount'] as num?)?.toDouble() ?? 0;
      final status = s['approvalStatus']?.toString() ?? '';
      if (status == 'PendingApproval' || status == 'Pending') pendingExp++;
    }

    double invValue = 0;
    int pendingInv = 0;
    for (final i in inventory) {
      invValue += i.totalCost;
      if (i.status == 'Pending') pendingInv++;
    }

    double assetVal = 0;
    for (final a in assets) assetVal += a.totalValue;

    setState(() {
      _totalRevenue = revenue;
      _totalCollected = collected;
      _activeOrderCount = activeOrders.length;
      _todayOrderCount = todayOrders.length;
      _overdueCount = overdue;
      _dueSoonCount = dueSoon;
      _onTrackCount = onTrack;
      _unpaidOrderCount = unpaidOrders.length;
      _unpaidBalance = unpaidBal;
      _pendingExpenseCount = pendingExp;
      _pendingInventoryCount = pendingInv;
      _totalExpenses = totalExp;
      _collectionRate = revenue > 0 ? (collected / revenue * 100) : 0;
      _estimatedProfit = collected - totalExp;
      _totalInventoryValue = invValue;
      _inventoryItemCount = inventory.length;
      _totalAssetValue = assetVal;
      _assetCount = assets.length;
      _loading = false;
    });
  }

  void _nav(String route) {
    Navigator.pushNamed(context, route).then((_) => _loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Gradient Header
            _buildHeader(),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadDashboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // Stats overlapping header
                            Transform.translate(
                              offset: const Offset(0, -30),
                              child: _buildStats(),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDeliveryTracking(),
                                  const SizedBox(height: 20),
                                  _buildNeedsAttention(),
                                  const SizedBox(height: 20),
                                  _buildFinancials(),
                                  const SizedBox(height: 20),
                                  _buildQuickActions(),
                                  const SizedBox(height: 20),
                                  _buildBusinessFinance(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SyncIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final name = provider.user?['name'] as String? ??
            provider.user?['fullName'] as String? ?? 'there';
        final hour = DateTime.now().hour;
        final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.header),
              bottomRight: Radius.circular(AppRadius.header),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Settings + Profile
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.settings_outlined,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'K. Fabrics',
                      style: TextStyle(
                        color: AppColors.gold.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          StatCard(
            icon: Icons.trending_up,
            iconColor: AppColors.success,
            value: Helpers.formatCurrency(_totalRevenue),
            label: 'Revenue',
            onTap: () => _nav('/payments'),
          ),
          StatCard(
            icon: Icons.payments,
            iconColor: AppColors.orange,
            value: Helpers.formatCurrency(_totalCollected),
            label: 'Collected',
            onTap: () => _nav('/payments'),
          ),
          StatCard(
            icon: Icons.list_alt,
            iconColor: AppColors.blue,
            value: '$_activeOrderCount',
            label: 'Active Orders',
            onTap: () => _nav('/today-orders'),
          ),
          StatCard(
            icon: Icons.today,
            iconColor: AppColors.primary,
            value: '$_todayOrderCount',
            label: "Today's Orders",
            onTap: () => _nav('/today-orders'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTracking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Delivery Status'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _deliveryPill('Overdue', _overdueCount, AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _deliveryPill('Due Soon', _dueSoonCount, AppColors.warning)),
            const SizedBox(width: 10),
            Expanded(child: _deliveryPill('On Track', _onTrackCount, AppColors.success)),
          ],
        ),
      ],
    );
  }

  Widget _deliveryPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNeedsAttention() {
    final items = <Widget>[];
    if (_unpaidOrderCount > 0) {
      items.add(_attentionRow(Icons.warning_amber_rounded,
          '$_unpaidOrderCount unpaid (${Helpers.formatCurrency(_unpaidBalance)})', AppColors.error,
          () => _nav('/today-orders')));
    }
    if (_overdueCount > 0) {
      items.add(_attentionRow(Icons.schedule, '$_overdueCount overdue orders',
          AppColors.error, () => _nav('/today-orders')));
    }
    if (_pendingExpenseCount > 0) {
      items.add(_attentionRow(Icons.receipt_long, '$_pendingExpenseCount pending expenses',
          AppColors.warning, () => _nav('/expenses')));
    }
    if (_pendingInventoryCount > 0) {
      items.add(_attentionRow(Icons.inventory_2, '$_pendingInventoryCount pending inventory',
          AppColors.warning, () => _nav('/inventory')));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Needs Attention', icon: Icons.notifications_active, iconColor: AppColors.warning),
        const SizedBox(height: 10),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _attentionRow(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text,
                style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500))),
            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Financials'),
        const SizedBox(height: 10),
        PremiumCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Collection Rate',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                  Text('${_collectionRate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _collectionRate / 100,
                  backgroundColor: AppColors.lavender,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _collectionRate >= 80 ? AppColors.success
                        : _collectionRate >= 50 ? AppColors.warning : AppColors.error,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              _finRow('Outstanding', Helpers.formatCurrency(_unpaidBalance), AppColors.error),
              _finRow('Expenses', Helpers.formatCurrency(_totalExpenses), AppColors.orange),
              _finRow('Est. Profit', Helpers.formatCurrency(_estimatedProfit),
                  _estimatedProfit >= 0 ? AppColors.success : AppColors.error),
            ],
          ),
        ),
        // Inventory & Assets row
        Row(
          children: [
            Expanded(
              child: _miniStat(Icons.inventory_2, 'Inventory', '$_inventoryItemCount items',
                  Helpers.formatCurrency(_totalInventoryValue), AppColors.purple,
                  () => _nav('/inventory')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniStat(Icons.devices, 'Assets', '$_assetCount items',
                  Helpers.formatCurrency(_totalAssetValue), AppColors.teal,
                  () => _nav('/assets')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _finRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String title, String subtitle, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _actionTile(Icons.content_cut, 'New Order', AppColors.primary, () => _nav('/new-order')),
            _actionTile(Icons.list_alt, 'Orders', AppColors.blue, () => _nav('/today-orders')),
            _actionTile(Icons.payments, 'Payments', AppColors.success, () => _nav('/payments')),
            _actionTile(Icons.inventory_2, 'Inventory', AppColors.purple, () => _nav('/inventory')),
            _actionTile(Icons.devices, 'Assets', AppColors.teal, () => _nav('/assets')),
            _actionTile(Icons.receipt_long, 'Expenses', AppColors.orange, () => _nav('/expenses')),
          ],
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CategoryIcon(icon: icon, color: color, size: 50),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessFinance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Business Finance', icon: Icons.account_balance_wallet, iconColor: AppColors.purpleBlue),
        const SizedBox(height: 10),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          child: Column(
            children: [
              _financeRow(Icons.account_balance_wallet, 'Partner Balances',
                  'View capital & balance', AppColors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnerBalancesScreen()))
                    .then((_) => _loadDashboard());
              }),
              Divider(height: 1, indent: 60, endIndent: 16, color: Colors.grey.shade100),
              _financeRow(Icons.add_circle_outline, 'Add Capital',
                  'Record capital transaction', AppColors.success, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCapitalScreen()))
                    .then((_) => _loadDashboard());
              }),
              Divider(height: 1, indent: 60, endIndent: 16, color: Colors.grey.shade100),
              _financeRow(Icons.receipt_long_outlined, 'Record Expense',
                  'Rent, salary, supplies', AppColors.orange, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSpendingScreen()))
                    .then((_) => _loadDashboard());
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _financeRow(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
          const SizedBox(width: 6),
        ],
        Text(title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }
}
