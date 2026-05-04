import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/photo_capture_widget.dart';
import '../utils/constants.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  int _currentStep = 0;

  // Step 1: Asset type
  String? _selectedType;

  // Step 2: Details
  String? _photoPath;
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitValueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Step 3: Owner (single partner)
  bool _loadingPartners = true;
  List<Map<String, dynamic>> _partners = [];
  Map<String, double> _partnerBalances = {};
  String? _selectedOwnerId;
  String? _selectedOwnerName;

  bool _saving = false;

  double get _totalValue {
    final qty = int.tryParse(_quantityController.text.trim()) ?? 1;
    final unit = double.tryParse(_unitValueController.text.trim()) ?? 0;
    return qty * unit;
  }

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitValueController.dispose();
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
      if (_selectedType == null) {
        _showSnack('Please select an asset type');
        return;
      }
    } else if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showSnack('Please enter an asset name');
        return;
      }
      final unitValue = double.tryParse(_unitValueController.text.trim()) ?? 0;
      if (unitValue <= 0) {
        _showSnack('Please enter a valid unit value');
        return;
      }
    } else if (_currentStep == 2) {
      if (_selectedOwnerId == null) {
        _showSnack('Please select an owner');
        return;
      }
      // Hard block: asset value must not exceed owner's available capital
      final ownerBalance = _partnerBalances[_selectedOwnerId];
      if (ownerBalance != null && _totalValue > ownerBalance) {
        _showSnack(
          '${_selectedOwnerName ?? "Owner"} does not have sufficient capital\n'
          'Asset value: PKR ${_totalValue.toStringAsFixed(0)} — Available: PKR ${ownerBalance.toStringAsFixed(0)}',
        );
        return;
      }
    }
    setState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final asset = Asset(
        name: _nameController.text.trim(),
        type: _selectedType!,
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        unitValue: double.parse(_unitValueController.text.trim()),
        owner: _selectedOwnerName ?? _selectedOwnerId ?? '',
        photoPath: _photoPath,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final id = await DatabaseService.insertAsset(asset);

      await SyncService.addToQueue(
        entityType: 'asset',
        entityId: id,
        action: 'create',
        payload: {
          ...asset.toJson(),
          'ownerId': _selectedOwnerId,
          'purchaseDate': _selectedDate.toIso8601String(),
        },
        filePath: _photoPath,
      );

      if (!mounted) return;
      Provider.of<AppProvider>(context, listen: false).refreshSyncCount();

      _showSuccessAndPop();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessAndPop() {
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
              const Text('Asset Saved!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Status: Pending Approval',
                  style: TextStyle(color: AppColors.orange)),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Asset'),
        backgroundColor: AppColors.teal,
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
            child: _loadingPartners && _currentStep == 2
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
    final steps = ['Type', 'Details', 'Owner', 'Review'];
    return Container(
      color: AppColors.teal,
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
                              ? const Icon(Icons.check, size: 16, color: AppColors.teal)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? AppColors.teal : Colors.white,
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

  // Step 1: Asset Type selection
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Asset Type',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('What kind of asset is this?',
            style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: AssetTypes.types.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.teal.withOpacity(0.12)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.teal : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: isSelected ? AppColors.teal : AppColors.textMedium,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.teal : AppColors.textDark,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, size: 18, color: AppColors.teal),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Next: Details', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 2: Asset details + photo
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Asset Details',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 20),

        // Photo
        PhotoCaptureWidget(
          photoPath: _photoPath,
          label: 'Take photo of asset (optional)',
          onPhotoCaptured: (path) => setState(() => _photoPath = path),
        ),
        const SizedBox(height: 16),

        // Name
        const Text('Asset Name',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Juki Sewing Machine',
          ),
        ),
        const SizedBox(height: 16),

        // Quantity and unit value
        const Text('Quantity & Value',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Qty'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Unit Value',
                  prefixText: 'PKR ',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (_totalValue > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, size: 16, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  'Total Value: PKR ${_totalValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Date
        const Text('Purchase Date',
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

        // Notes
        const Text('Notes (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Condition, serial number, etc.',
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Next: Owner', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 3: Owner selection — single partner with capital display
  Widget _buildStep3() {
    if (_loadingPartners) {
      return const Center(child: CircularProgressIndicator());
    }

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
            'Add a business partner first before recording an asset.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPartners,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Asset Owner',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text(
          'Select which partner owns this asset. Their capital will be used.',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),

        // Total value reminder
        if (_totalValue > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text(
                  'Asset Value: PKR ${_totalValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        ..._partners.map((p) {
          final id = (p['id'] ?? p['partnerId']).toString();
          final name = p['userName'] as String? ??
              p['name'] as String? ??
              p['partnerName'] as String? ??
              id;
          final isSelected = _selectedOwnerId == id;
          final balance = _partnerBalances[id];
          final hasEnoughCapital =
              balance == null || _totalValue == 0 || balance >= _totalValue;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedOwnerId = id;
              _selectedOwnerName = name;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.teal.withOpacity(0.1)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.teal
                      : !hasEnoughCapital
                          ? AppColors.error.withOpacity(0.3)
                          : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isSelected
                        ? AppColors.teal.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.teal : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.teal : AppColors.textDark,
                          ),
                        ),
                        if (balance != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                'Available: PKR ${balance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasEnoughCapital
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!hasEnoughCapital && _totalValue > 0) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.error),
                                const SizedBox(width: 2),
                                const Text(
                                  'Insufficient',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.teal, size: 24),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Next: Review', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // Step 4: Review & Submit
  Widget _buildStep4() {
    final ownerBalance = _partnerBalances[_selectedOwnerId];
    final afterBalance =
        ownerBalance != null ? ownerBalance - _totalValue : null;

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
                _reviewRow('Type', _selectedType ?? ''),
                const Divider(height: 16),
                _reviewRow('Name', _nameController.text.trim()),
                const Divider(height: 16),
                _reviewRow(
                  'Quantity',
                  '${_quantityController.text.trim()} × PKR ${(double.tryParse(_unitValueController.text.trim()) ?? 0).toStringAsFixed(0)}',
                ),
                const Divider(height: 16),
                _reviewRow(
                  'Total Value',
                  'PKR ${_totalValue.toStringAsFixed(0)}',
                  valueColor: AppColors.teal,
                  valueBold: true,
                ),
                const Divider(height: 16),
                _reviewRow('Purchase Date', DateFormat('dd MMM yyyy').format(_selectedDate)),
                if (_notesController.text.trim().isNotEmpty) ...[
                  const Divider(height: 16),
                  _reviewRow('Notes', _notesController.text.trim()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Owner card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.teal.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.teal.withOpacity(0.2),
                child: Text(
                  _selectedOwnerName?.isNotEmpty == true
                      ? _selectedOwnerName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.teal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedOwnerName ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    if (ownerBalance != null)
                      Text(
                        'Balance after purchase: PKR ${afterBalance!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMedium),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Owner',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.save),
            label: Text(
              _saving ? 'Saving...' : 'Save as Pending',
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
