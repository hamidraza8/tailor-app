import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class AddSpendingScreen extends StatefulWidget {
  const AddSpendingScreen({super.key});

  @override
  State<AddSpendingScreen> createState() => _AddSpendingScreenState();
}

class _AddSpendingScreenState extends State<AddSpendingScreen> {
  int _currentStep = 0;

  // Step 1: Category
  String? _selectedCategory;

  // Step 2: Amount & Details
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Step 3: Partners & splits
  bool _loadingPartners = true;
  List<Map<String, dynamic>> _partners = [];
  Map<String, double> _partnerBalances = {};
  final Map<String, TextEditingController> _splitControllers = {};

  bool _saving = false;

  // 'key' is used for local selection; 'apiId' is sent to the server
  static const List<Map<String, dynamic>> _categories = [
    {'key': 'AssetPurchase', 'apiId': 'AssetPurchase', 'label': 'Asset Purchase', 'icon': Icons.build},
    {'key': 'Inventory',     'apiId': 'InventoryPurchase', 'label': 'Inventory',  'icon': Icons.inventory},
    {'key': 'Rent',          'apiId': 'Rent',          'label': 'Rent',           'icon': Icons.home},
    {'key': 'Utility',       'apiId': 'Utility',       'label': 'Utility',        'icon': Icons.bolt},
    {'key': 'Salary',        'apiId': 'Salary',        'label': 'Salary',         'icon': Icons.people},
    {'key': 'Labour',        'apiId': 'Labour',        'label': 'Labour',         'icon': Icons.construction},
    {'key': 'Marketing',     'apiId': 'Marketing',     'label': 'Marketing',      'icon': Icons.campaign},
    {'key': 'Supplies',      'apiId': 'Misc',          'label': 'Thread & Supplies', 'icon': Icons.cut},
    {'key': 'Transport',     'apiId': 'Misc',          'label': 'Transport',      'icon': Icons.directions_car},
    {'key': 'Packaging',     'apiId': 'Misc',          'label': 'Packaging',      'icon': Icons.shopping_bag},
    {'key': 'Misc',          'apiId': 'Misc',          'label': 'Other',          'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _notesController.dispose();
    for (final c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPartners() async {
    setState(() => _loadingPartners = true);

    final results = await Future.wait([
      ApiService.get('/partners'),
      ApiService.get('/reports/partner-balances'),
    ]);

    if (!mounted) return;

    final partnerResult = results[0];
    final balanceResult = results[1];

    List<Map<String, dynamic>> partners = [];
    if (partnerResult['success'] == true) {
      final data = partnerResult['data'];
      if (data is List) {
        partners = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    final Map<String, double> balances = {};
    if (balanceResult['success'] == true) {
      final data = balanceResult['data'];
      List items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data['partnerBalances'] is List) {
        items = data['partnerBalances'] as List;
      }
      for (final item in items) {
        final m = item as Map;
        final id = (m['partnerId'] ?? m['id']).toString();
        balances[id] = (m['remainingBalance'] as num? ?? 0).toDouble();
      }
    }

    // Create a controller for each partner
    for (final p in partners) {
      final id = (p['id'] ?? p['partnerId']).toString();
      _splitControllers[id] = TextEditingController();
    }

    setState(() {
      _partners = partners;
      _partnerBalances = balances;
      _loadingPartners = false;
    });
  }

  double get _totalAmount =>
      double.tryParse(_totalAmountController.text.trim()) ?? 0;

  double get _splitTotal {
    double total = 0;
    for (final c in _splitControllers.values) {
      total += double.tryParse(c.text.trim()) ?? 0;
    }
    return total;
  }

  bool get _splitBalanced => (_splitTotal - _totalAmount).abs() < 0.01;

  void _splitEqually() {
    if (_partners.isEmpty) return;
    final each = _totalAmount / _partners.length;
    for (final c in _splitControllers.values) {
      c.text = each.toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _goNext() {
    if (_currentStep == 0) {
      if (_selectedCategory == null) {
        _showSnack('Please select a category');
        return;
      }
    } else if (_currentStep == 1) {
      if (_descriptionController.text.trim().isEmpty) {
        _showSnack('Please enter a description');
        return;
      }
      if (_totalAmount <= 0) {
        _showSnack('Please enter a valid amount');
        return;
      }
    } else if (_currentStep == 2) {
      if (!_splitBalanced) {
        _showSnack('Split total must equal the spending amount');
        return;
      }
      // Hard block: each partner's contribution must not exceed their available capital
      if (_partnerBalances.isNotEmpty) {
        for (final p in _partners) {
          final id = (p['id'] ?? p['partnerId']).toString();
          final name = p['userName'] as String? ??
              p['name'] as String? ??
              p['partnerName'] as String? ??
              id;
          final splitAmount =
              double.tryParse(_splitControllers[id]?.text.trim() ?? '') ?? 0;
          if (splitAmount > 0) {
            final balance = _partnerBalances[id] ?? 0;
            if (splitAmount > balance) {
              _showSnack(
                '$name does not have sufficient capital\nAvailable: PKR ${balance.toStringAsFixed(0)}',
              );
              return;
            }
          }
        }
      }
    }

    setState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);

    // Build splits list
    final splits = <Map<String, dynamic>>[];
    for (final p in _partners) {
      final id = (p['id'] ?? p['partnerId']).toString();
      final amount = double.tryParse(_splitControllers[id]?.text.trim() ?? '') ?? 0;
      if (amount > 0) {
        splits.add({'partnerId': id, 'amount': amount});
      }
    }

    final apiCategory = _categories
        .firstWhere((c) => c['key'] == _selectedCategory,
            orElse: () => {'apiId': 'Misc'})['apiId'] as String;

    final resultType = apiCategory == 'AssetPurchase'
        ? 'Asset'
        : apiCategory == 'InventoryPurchase'
            ? 'Inventory'
            : 'Expense';

    final payload = {
      'category': apiCategory,
      'description': _descriptionController.text.trim(),
      'totalAmount': _totalAmount,
      'spendingDate': _selectedDate.toIso8601String(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'resultType': resultType,
      'ownershipApplicable': apiCategory == 'AssetPurchase',
      'fundingSplits': splits,
    };

    final online = await SyncService.isOnline();

    if (online) {
      final result = await ApiService.post('/spendings', payload);
      if (!mounted) return;
      setState(() => _saving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spending submitted for approval!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showSnack(result['message'] as String? ?? result['error'] as String? ?? 'Failed to submit spending');
      }
    } else {
      await SyncService.addToQueue(
        entityType: 'expense',
        entityId: DateTime.now().millisecondsSinceEpoch % 2000000000,
        action: 'create',
        payload: payload,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Provider.of<AppProvider>(context, listen: false).syncNow();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved offline — will sync when online'),
          backgroundColor: AppColors.warning,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Expense'),
        backgroundColor: AppColors.orange,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: _loadingPartners && _currentStep >= 2
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildCurrentStep(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Category', 'Details', 'Funding', 'Review'];
    return Container(
      color: AppColors.orange,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isDone = i < _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone || isCurrent
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, size: 16, color: AppColors.orange)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? AppColors.orange
                                        : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrent || isDone
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: Colors.white.withOpacity(isDone ? 0.8 : 0.3),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Category selection
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Category',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'What type of spending is this?',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat['key'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.orange.withOpacity(0.15)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.orange
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 28,
                      color: isSelected ? AppColors.orange : AppColors.textMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.orange : AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Next: Amount & Details',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 2: Amount & Details
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount & Details',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 20),

        // Description
        const Text('Description',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What is this spending for?'),
        ),
        const SizedBox(height: 16),

        // Total amount
        const Text('Total Amount',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: _totalAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            prefixText: 'PKR ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Date picker
        const Text('Date',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        const Text('Notes (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              const InputDecoration(hintText: 'Optional notes...'),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Next: Funding Split', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 3: Funding split — shows available capital per partner
  Widget _buildStep3() {
    if (_loadingPartners) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_partners.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.people_outline, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          const Text(
            'No Partners Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'You need at least one business partner before recording a funded expense.\n\nGo to Partner Balances → Add Partner first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPartners,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
          ),
        ],
      );
    }

    final balanced = _splitBalanced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who is Funding This?',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter how much each partner is contributing. Tap "Split Equally" to divide automatically.',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
        const SizedBox(height: 16),

        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: balanced
                ? AppColors.success.withOpacity(0.08)
                : AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: balanced
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.warning.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Split: PKR ${_splitTotal.toStringAsFixed(0)} / Total: PKR ${_totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: balanced ? AppColors.success : AppColors.warning,
                ),
              ),
              Icon(
                balanced ? Icons.check_circle : Icons.warning_amber_rounded,
                color: balanced ? AppColors.success : AppColors.warning,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Split equally button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _totalAmount > 0 ? _splitEqually : null,
            icon: const Icon(Icons.call_split, size: 16),
            label: const Text('Split Equally'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),

        // Per-partner rows with available capital
        ..._partners.map((p) {
          final id = (p['id'] ?? p['partnerId']).toString();
          final name = p['userName'] as String? ??
              p['name'] as String? ??
              p['partnerName'] as String? ??
              id;
          final availableCapital = _partnerBalances[id];
          final enteredAmount =
              double.tryParse(_splitControllers[id]?.text.trim() ?? '') ?? 0;
          final exceedsCapital = availableCapital != null &&
              enteredAmount > 0 &&
              enteredAmount > availableCapital;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark)),
                          if (availableCapital != null)
                            Text(
                              'Available: PKR ${availableCapital.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: availableCapital > 0
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _splitControllers[id],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'PKR ',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: exceedsCapital
                                  ? AppColors.error
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: exceedsCapital
                                  ? AppColors.error
                                  : AppColors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (exceedsCapital)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 48),
                    child: Text(
                      'Exceeds available capital',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Next: Review', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 4: Review & Submit
  Widget _buildStep4() {
    final splits = <Map<String, dynamic>>[];
    for (final p in _partners) {
      final id = (p['id'] ?? p['partnerId']).toString();
      final name = p['userName'] as String? ??
          p['name'] as String? ??
          p['partnerName'] as String? ??
          id;
      final amount =
          double.tryParse(_splitControllers[id]?.text.trim() ?? '') ?? 0;
      if (amount > 0) {
        splits.add({'id': id, 'name': name, 'amount': amount});
      }
    }

    final catLabel = _categories
        .firstWhere((c) => c['key'] == _selectedCategory,
            orElse: () => {'label': _selectedCategory ?? ''})['label'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Submit',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 16),

        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewRow('Category', catLabel),
                const Divider(height: 16),
                _reviewRow('Description', _descriptionController.text.trim()),
                const Divider(height: 16),
                _reviewRow(
                  'Total Amount',
                  'PKR ${_totalAmount.toStringAsFixed(0)}',
                  valueColor: AppColors.textDark,
                  valueBold: true,
                ),
                const Divider(height: 16),
                _reviewRow(
                    'Date', DateFormat('dd MMM yyyy').format(_selectedDate)),
                if (_notesController.text.trim().isNotEmpty) ...[
                  const Divider(height: 16),
                  _reviewRow('Notes', _notesController.text.trim()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Splits
        const Text(
          'Funding Splits',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        ...splits.map((s) {
          final partnerId = s['id'] as String;
          final partnerName = s['name'] as String;
          final amount = s['amount'] as double;
          final currentBalance = _partnerBalances[partnerId];
          final afterBalance =
              currentBalance != null ? currentBalance - amount : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.success.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partnerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      if (currentBalance != null)
                        Text(
                          'Balance after: PKR ${afterBalance!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMedium),
                        ),
                    ],
                  ),
                ),
                Text(
                  'PKR ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.send),
            label: Text(
              _saving ? 'Submitting...' : 'Submit for Approval',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _reviewRow(String label, String value,
      {Color? valueColor, bool valueBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.textDark,
              fontWeight:
                  valueBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
