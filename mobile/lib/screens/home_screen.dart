import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/big_action_button.dart';
import '../widgets/sync_indicator.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/inventory.dart';
import '../models/asset.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
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

  // Quick stats
  double _totalRevenue = 0;
  double _totalCollected = 0;
  int _activeOrderCount = 0;
  int _todayOrderCount = 0;

  // Delivery
  int _overdueCount = 0;
  int _dueSoonCount = 0;
  int _onTrackCount = 0;

  // Attention
  int _unpaidOrderCount = 0;
  double _unpaidBalance = 0;
  int _pendingExpenseCount = 0;
  int _pendingInventoryCount = 0;

  // Financials
  double _totalExpenses = 0;
  double _totalBalance = 0;
  double _collectionRate = 0;
  double _estimatedProfit = 0;

  // Inventory & Assets
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
      DatabaseService.getOrders(),                // 0
      DatabaseService.getActiveOrders(),           // 1
      DatabaseService.getTodayOrders(),            // 2
      DatabaseService.getOrdersWithBalance(),      // 3
      DatabaseService.getAllPayments(),             // 4
      ApiService.get('/spendings'),                // 5 - spendings from server
      DatabaseService.getInventoryTransactions(),  // 6
      DatabaseService.getAssets(),                 // 7
    ]);

    final allOrders = results[0] as List<Order>;
    final activeOrders = results[1] as List<Order>;
    final todayOrders = results[2] as List<Order>;
    final unpaidOrders = results[3] as List<Order>;
    final payments = results[4] as List<Payment>;
    final spendingsResult = results[5] as Map<String, dynamic>;
    final spendingsRaw = spendingsResult['success'] == true && spendingsResult['data'] is List
        ? (spendingsResult['data'] as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final inventory = results[6] as List<InventoryTransaction>;
    final assets = results[7] as List<Asset>;

    // Revenue
    double revenue = 0;
    for (final o in allOrders) {
      revenue += o.totalAmount;
    }

    // Collections
    double collected = 0;
    for (final p in payments) {
      collected += p.amount;
    }

    // Unpaid
    double unpaidBal = 0;
    for (final o in unpaidOrders) {
      unpaidBal += o.balanceAmount;
    }

    // Delivery tracking
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    int overdue = 0, dueSoon = 0, onTrack = 0;
    for (final o in activeOrders) {
      if (o.dueDate != null) {
        if (o.dueDate!.isBefore(now)) {
          overdue++;
        } else if (o.dueDate!.isBefore(weekFromNow)) {
          dueSoon++;
        } else {
          onTrack++;
        }
      } else {
        onTrack++;
      }
    }

    // Expenses (from spendings with ResultType = Expense)
    double totalExp = 0;
    int pendingExp = 0;
    for (final s in spendingsRaw) {
      totalExp += (s['totalAmount'] as num?)?.toDouble() ?? 0;
      final status = s['approvalStatus']?.toString() ?? '';
      if (status == 'PendingApproval' || status == 'Pending') pendingExp++;
    }

    // Inventory
    double invValue = 0;
    int pendingInv = 0;
    for (final i in inventory) {
      invValue += i.totalCost;
      if (i.status == 'Pending') pendingInv++;
    }

    // Assets
    double assetVal = 0;
    for (final a in assets) {
      assetVal += a.totalValue;
    }

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
      _totalBalance = unpaidBal;
      _collectionRate = revenue > 0 ? (collected / revenue * 100) : 0;
      _estimatedProfit = collected - totalExp;
      _totalInventoryValue = invValue;
      _inventoryItemCount = inventory.length;
      _totalAssetValue = assetVal;
      _assetCount = assets.length;
      _loading = false;
    });
  }

  void _navigateAndRefresh(String route) {
    Navigator.pushNamed(context, route).then((_) => _loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut, size: 24),
            SizedBox(width: 8),
            Text('Tailor App'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(),
                          const SizedBox(height: 16),
                          _buildQuickStats(),
                          const SizedBox(height: 20),
                          _buildDeliveryTracking(),
                          const SizedBox(height: 20),
                          _buildNeedsAttention(),
                          const SizedBox(height: 20),
                          _buildFinancials(),
                          const SizedBox(height: 20),
                          _buildInventoryAssets(),
                          const SizedBox(height: 24),
                          _buildBusinessFinance(),
                          const SizedBox(height: 20),
                          _buildQuickActions(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
          const SyncIndicator(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final name = provider.user?['name'] as String? ?? 'there';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $name!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _statCard('Revenue', Helpers.formatCurrency(_totalRevenue), Icons.trending_up, AppColors.green),
        _statCard('Collections', Helpers.formatCurrency(_totalCollected), Icons.payments, AppColors.orange),
        _statCard('Active Orders', '$_activeOrderCount', Icons.list_alt, AppColors.blue),
        _statCard("Today's Orders", '$_todayOrderCount', Icons.today, AppColors.teal),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDeliveryTracking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _deliveryBox('Overdue', '$_overdueCount', AppColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _deliveryBox('Due Soon', '$_dueSoonCount', AppColors.warning)),
            const SizedBox(width: 10),
            Expanded(child: _deliveryBox('On Track', '$_onTrackCount', AppColors.success)),
          ],
        ),
      ],
    );
  }

  Widget _deliveryBox(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNeedsAttention() {
    final items = <Widget>[];

    if (_unpaidOrderCount > 0) {
      items.add(_attentionRow(
        Icons.warning_amber_rounded,
        '$_unpaidOrderCount unpaid orders (${Helpers.formatCurrency(_unpaidBalance)})',
        AppColors.error,
        () => _navigateAndRefresh('/today-orders'),
      ));
    }
    if (_overdueCount > 0) {
      items.add(_attentionRow(
        Icons.schedule,
        '$_overdueCount overdue orders',
        AppColors.error,
        () => _navigateAndRefresh('/today-orders'),
      ));
    }
    if (_pendingExpenseCount > 0) {
      items.add(_attentionRow(
        Icons.receipt_long,
        '$_pendingExpenseCount pending expenses',
        AppColors.warning,
        () => _navigateAndRefresh('/expenses'),
      ));
    }
    if (_pendingInventoryCount > 0) {
      items.add(_attentionRow(
        Icons.inventory_2,
        '$_pendingInventoryCount pending inventory items',
        AppColors.warning,
        () => _navigateAndRefresh('/inventory'),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active, size: 18, color: AppColors.warning),
            SizedBox(width: 6),
            Text('Needs Attention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _attentionRow(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Collection rate with progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Collection Rate', style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                    Text('${_collectionRate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _collectionRate / 100,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _collectionRate >= 80 ? AppColors.success : _collectionRate >= 50 ? AppColors.warning : AppColors.error,
                    ),
                    minHeight: 6,
                  ),
                ),
                const Divider(height: 24),
                _finRow('Outstanding', Helpers.formatCurrency(_totalBalance), AppColors.error),
                const SizedBox(height: 8),
                _finRow('Expenses', Helpers.formatCurrency(_totalExpenses), AppColors.red),
                const SizedBox(height: 8),
                _finRow('Est. Profit', Helpers.formatCurrency(_estimatedProfit),
                    _estimatedProfit >= 0 ? AppColors.success : AppColors.error),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _finRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
      ],
    );
  }

  Widget _buildInventoryAssets() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _navigateAndRefresh('/inventory'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 18, color: AppColors.purple),
                      const SizedBox(width: 6),
                      const Text('Inventory', style: TextStyle(fontSize: 13, color: AppColors.purple, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$_inventoryItemCount items', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  Text(Helpers.formatCurrency(_totalInventoryValue), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.purple)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _navigateAndRefresh('/assets'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.teal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.devices, size: 18, color: AppColors.teal),
                      SizedBox(width: 6),
                      Text('Assets', style: TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$_assetCount items', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  Text(Helpers.formatCurrency(_totalAssetValue), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.teal)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessFinance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet, size: 18, color: AppColors.blue),
            SizedBox(width: 6),
            Text(
              'Business Finance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _financeActionRow(
                  Icons.account_balance_wallet,
                  'Partner Balances',
                  'View capital & balance per partner',
                  AppColors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PartnerBalancesScreen()),
                  ).then((_) => _loadDashboard()),
                ),
                const Divider(height: 1, indent: 52),
                _financeActionRow(
                  Icons.add_circle,
                  'Add Capital',
                  'Record a capital transaction',
                  AppColors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddCapitalScreen()),
                  ).then((_) => _loadDashboard()),
                ),
                const Divider(height: 1, indent: 52),
                _financeActionRow(
                  Icons.receipt_long,
                  'Record Expense',
                  'Record rent, salary, supplies & more',
                  AppColors.orange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddSpendingScreen()),
                  ).then((_) => _loadDashboard()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _financeActionRow(
      IconData icon, String label, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions / فوری اقدامات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 12),
        BigActionButton(
          label: 'New Order', urduLabel: 'نیا آرڈر', icon: Icons.content_cut, color: AppColors.green,
          onTap: () => _navigateAndRefresh('/new-order'),
        ),
        const SizedBox(height: 10),
        BigActionButton(
          label: "Today's Orders", urduLabel: 'آج کے آرڈرز', icon: Icons.list_alt, color: AppColors.blue,
          onTap: () => _navigateAndRefresh('/today-orders'),
        ),
        const SizedBox(height: 10),
        BigActionButton(
          label: 'Payments', urduLabel: 'ادائیگیاں', icon: Icons.payments, color: AppColors.orange,
          onTap: () => _navigateAndRefresh('/payments'),
        ),
        const SizedBox(height: 10),
        BigActionButton(
          label: 'Inventory', urduLabel: 'سامان', icon: Icons.inventory_2, color: AppColors.purple,
          onTap: () => _navigateAndRefresh('/inventory'),
        ),
        const SizedBox(height: 10),
        BigActionButton(
          label: 'Assets', urduLabel: 'اثاثے', icon: Icons.devices, color: AppColors.teal,
          onTap: () => _navigateAndRefresh('/assets'),
        ),
        const SizedBox(height: 10),
        BigActionButton(
          label: 'Expenses', urduLabel: 'اخراجات', icon: Icons.receipt_long, color: AppColors.red,
          onTap: () => _navigateAndRefresh('/expenses'),
        ),
      ],
    );
  }
}
