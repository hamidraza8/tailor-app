import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import 'add_partner_screen.dart';

class PartnerBalancesScreen extends StatefulWidget {
  const PartnerBalancesScreen({super.key});

  @override
  State<PartnerBalancesScreen> createState() => _PartnerBalancesScreenState();
}

class _PartnerBalancesScreenState extends State<PartnerBalancesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _partners = [];
  double _totalCapital = 0;
  double _totalSpent = 0;
  double _totalRemaining = 0;
  bool _isAdmin = false;

  // Track which cards are expanded
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppProvider>(context, listen: false).user;
    final role = user?['role'];
    _isAdmin = role == 'Admin' || role?.toString().toLowerCase() == 'admin';
    _loadData();
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

  Future<void> _deletePartner(Map<String, dynamic> partner) async {
    final id = (partner['partnerId'] ?? partner['id'])?.toString() ?? '';
    final name = partner['partnerName'] as String? ??
        partner['name'] as String? ??
        'this partner';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner ID not available.')),
      );
      return;
    }
    final confirm = await _confirmDelete(context, name);
    if (!confirm || !mounted) return;
    await SyncService.addToQueue(
      entityType: 'partner',
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

  void _showEditPartnerSheet(
      BuildContext context, Map<String, dynamic> partner) {
    final id = (partner['partnerId'] ?? partner['id'])?.toString() ?? '';
    final profitCtrl = TextEditingController(
        text: (partner['profitSharePercentage'] as num? ?? 0)
            .toStringAsFixed(0));
    final labourCtrl = TextEditingController(
        text: (partner['labourSharePercentage'] as num? ?? 0)
            .toStringAsFixed(0));
    final notesCtrl =
        TextEditingController(text: partner['notes']?.toString() ?? '');

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
            const Text('Edit Partner',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: profitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Profit Share %'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labourCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Labour Share %'),
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
                  if (id.isEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Partner ID not available.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await SyncService.addToQueue(
                    entityType: 'partner',
                    entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
                    action: 'update',
                    payload: {
                      'id': id,
                      'profitSharePercentage': double.tryParse(profitCtrl.text.trim()) ?? 0,
                      'labourSharePercentage': double.tryParse(labourCtrl.text.trim()) ?? 0,
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.get('/reports/partner-balances');

    if (!mounted) return;

    if (result['success'] == true) {
      // API returns CapitalSummaryDto spread at top level:
      // { partnerBalances: [...], totalBusinessCapital, ... }
      List<Map<String, dynamic>> partners = [];
      final raw = result['partnerBalances'] ?? result['data'];
      if (raw is List) {
        partners = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      double totalCap = 0, totalSpent = 0, totalRem = 0;
      for (final p in partners) {
        totalCap += (p['totalCapitalAdded'] as num? ?? 0).toDouble();
        totalSpent += (p['totalFundedSpendings'] as num? ?? 0).toDouble();
        totalRem += (p['remainingBalance'] as num? ?? 0).toDouble();
      }

      setState(() {
        _partners = partners;
        _totalCapital = totalCap;
        _totalSpent = totalSpent;
        _totalRemaining = totalRem;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to load partner balances';
        _loading = false;
      });
    }
  }

  String _formatPkr(dynamic value) {
    final amount = (value as num? ?? 0).toDouble();
    return 'PKR ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Balances'),
        backgroundColor: AppColors.primary,
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.blue,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPartnerScreen()),
              ).then((_) => _loadData()),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Partner', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(),
                        const SizedBox(height: 20),
                        const Text(
                          'Partners',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._partners.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPartnerCard(entry.key, entry.value),
                          );
                        }),
                        if (_partners.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No partner data available.',
                                style: TextStyle(color: AppColors.textMedium),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          Expanded(child: _summaryItem('Total Capital', _totalCapital, AppColors.blue)),
          _divider(),
          Expanded(child: _summaryItem('Total Spent', _totalSpent, AppColors.red)),
          _divider(),
          Expanded(
            child: _summaryItem(
              'Remaining',
              _totalRemaining,
              _totalRemaining >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'PKR ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.primary.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildPartnerCard(int index, Map<String, dynamic> partner) {
    final name = partner['partnerName'] as String? ?? partner['name'] as String? ?? 'Unknown';
    final remaining = (partner['remainingBalance'] as num? ?? 0).toDouble();
    final isDeficit = partner['isDeficit'] as bool? ?? remaining < 0;
    final isExpanded = _expanded.contains(index);

    final balanceColor = isDeficit ? AppColors.error : AppColors.success;

    return Card(
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expanded.remove(index);
            } else {
              _expanded.add(index);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (isDeficit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEFICIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showEditPartnerSheet(context, partner),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, size: 18, color: AppColors.blue),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deletePartner(partner),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete, size: 18, color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatPkr(remaining),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: balanceColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isDeficit ? 'Deficit balance' : 'Remaining balance',
                style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),

              // Expanded detail
              if (isExpanded) ...[
                const Divider(height: 20),
                _detailRow(
                  Icons.add_circle_outline,
                  'Capital Added',
                  _formatPkr(partner['totalCapitalAdded']),
                  AppColors.blue,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  Icons.money_off,
                  'Funded Spendings',
                  _formatPkr(partner['totalFundedSpendings']),
                  AppColors.red,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  Icons.devices,
                  'Asset Ownership Value',
                  _formatPkr(partner['assetOwnershipValue'] ?? partner['totalAssetValue']),
                  AppColors.purple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
