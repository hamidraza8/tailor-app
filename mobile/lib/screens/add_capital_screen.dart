import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class AddCapitalScreen extends StatefulWidget {
  const AddCapitalScreen({super.key});

  @override
  State<AddCapitalScreen> createState() => _AddCapitalScreenState();
}

class _AddCapitalScreenState extends State<AddCapitalScreen> {
  int _currentStep = 0;

  // Step 1: Partner
  bool _loadingPartners = true;
  List<Map<String, dynamic>> _partners = [];
  Map<String, double> _partnerBalances = {};
  String? _selectedPartnerId;
  String? _selectedPartnerName;

  // Step 2: Transaction type
  String? _selectedType;

  // Step 3: Details
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _saving = false;

  static const List<Map<String, dynamic>> _transactionTypes = [
    {
      'key': 'AdditionalCapital',
      'label': 'Add Capital',
      'desc': 'Partner deposits new money into the business',
      'icon': Icons.add_circle_outline,
      'color': AppColors.success,
    },
    {
      'key': 'CapitalAdvance',
      'label': 'Advance',
      'desc': 'Business advances funds to partner',
      'icon': Icons.account_balance_wallet,
      'color': AppColors.blue,
    },
    {
      'key': 'Withdrawal',
      'label': 'Withdrawal',
      'desc': 'Partner withdraws capital from business',
      'icon': Icons.call_missed_outgoing,
      'color': AppColors.error,
    },
    {
      'key': 'Adjustment',
      'label': 'Adjustment',
      'desc': 'Manually correct partner balance',
      'icon': Icons.tune,
      'color': AppColors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
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
    } else {
      _showSnack(partnerResult['message'] as String? ?? 'Failed to load partners');
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

    setState(() {
      _partners = partners;
      _partnerBalances = balances;
      _loadingPartners = false;
    });
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
      if (_selectedPartnerId == null) {
        _showSnack('Please select a partner');
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedType == null) {
        _showSnack('Please select a transaction type');
        return;
      }
    } else if (_currentStep == 2) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (amount <= 0) {
        _showSnack('Please enter a valid amount');
        return;
      }
    }
    setState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);

    final payload = {
      'partnerId': _selectedPartnerId,
      'transactionType': _selectedType,
      'amount': double.parse(_amountController.text.trim()),
      'transactionDate': _selectedDate.toIso8601String(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    final online = await SyncService.isOnline();

    if (online) {
      final result = await ApiService.post(
        '/capital-transactions/partner/$_selectedPartnerId',
        payload,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capital transaction saved!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showSnack(result['message'] as String? ?? 'Failed to save transaction');
      }
    } else {
      await SyncService.addToQueue(
        entityType: 'capital',
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Capital'),
        backgroundColor: AppColors.blue,
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
            child: _loadingPartners && _currentStep == 0
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
    final steps = ['Partner', 'Type', 'Details', 'Review'];
    return Container(
      color: AppColors.blue,
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
                              ? const Icon(Icons.check, size: 16, color: AppColors.blue)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? AppColors.blue : Colors.white,
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
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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

  // Step 1: Select Partner — shows current capital balance on each card
  Widget _buildStep1() {
    if (_partners.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.people_outline, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          const Text('No Partners Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Add a business partner first before recording a capital transaction.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPartners,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Partner',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('Which partner is this transaction for?',
            style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
          children: _partners.map((p) {
            final id = (p['id'] ?? p['partnerId']).toString();
            final name = p['userName'] as String? ??
                p['name'] as String? ??
                p['partnerName'] as String? ??
                id;
            final isSelected = _selectedPartnerId == id;
            final balance = _partnerBalances[id];
            final isPositive = balance == null || balance >= 0;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedPartnerId = id;
                _selectedPartnerName = name;
              }),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blue.withOpacity(0.12)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.blue : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isSelected
                          ? AppColors.blue.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.blue : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.blue : AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (balance != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isPositive ? AppColors.success : AppColors.error)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PKR ${balance.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            child: const Text('Next: Transaction Type',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 2: Transaction Type — with descriptions and partner context banner
  Widget _buildStep2() {
    final balance = _partnerBalances[_selectedPartnerId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transaction Type',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('Select what kind of capital movement this is',
            style: TextStyle(fontSize: 13, color: AppColors.textMedium)),

        // Selected partner context banner
        if (_selectedPartnerName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.blue.withOpacity(0.15),
                  child: Text(
                    _selectedPartnerName![0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedPartnerName!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                if (balance != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Current Capital',
                        style: TextStyle(fontSize: 10, color: AppColors.textMedium),
                      ),
                      Text(
                        'PKR ${balance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: _transactionTypes.map((type) {
            final isSelected = _selectedType == type['key'];
            final color = type['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type['key'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 28,
                      color: isSelected ? color : AppColors.textMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type['desc'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? color.withOpacity(0.8)
                            : AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            child: const Text('Next: Amount & Details',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 3: Amount & Details
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount & Details',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 20),

        const Text('Amount',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '0',
            prefixText: 'PKR ',
          ),
        ),
        const SizedBox(height: 16),

        const Text('Date',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Notes (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Optional notes...'),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            child: const Text('Next: Review', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 4: Review & Submit
  Widget _buildStep4() {
    final typeLabel = _transactionTypes
        .firstWhere((t) => t['key'] == _selectedType,
            orElse: () => {'label': _selectedType ?? ''})['label'] as String;
    final typeColor = _transactionTypes
        .firstWhere((t) => t['key'] == _selectedType,
            orElse: () => {'color': AppColors.blue})['color'] as Color;
    final typeIcon = _transactionTypes
        .firstWhere((t) => t['key'] == _selectedType,
            orElse: () => {'icon': Icons.payment})['icon'] as IconData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review & Submit',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewRow('Partner', _selectedPartnerName ?? ''),
                const Divider(height: 20),
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Type',
                          style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 6),
                          Text(typeLabel,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _reviewRow(
                  'Amount',
                  'PKR ${(double.tryParse(_amountController.text.trim()) ?? 0).toStringAsFixed(0)}',
                  valueColor: AppColors.textDark,
                  valueBold: true,
                ),
                const Divider(height: 20),
                _reviewRow('Date', DateFormat('dd MMM yyyy').format(_selectedDate)),
                if (_notesController.text.trim().isNotEmpty) ...[
                  const Divider(height: 20),
                  _reviewRow('Notes', _notesController.text.trim()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.save),
            label: Text(
              _saving ? 'Saving...' : 'Save Transaction',
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
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.textDark,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
