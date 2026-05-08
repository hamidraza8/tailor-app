import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/measurement.dart';
import '../models/payment.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../widgets/photo_capture_widget.dart';
import '../widgets/amount_input.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 1: Customer
  Customer? _selectedCustomer;
  final _customerSearchController = TextEditingController();
  final _newNameController = TextEditingController();
  final _newPhoneController = TextEditingController();
  List<Customer> _customers = [];
  bool _addingNew = false;

  // Step 2: Order Type
  String? _selectedOrderType;

  // Step 3: Design Photo
  String? _designPhotoPath;

  // Step 4: Measurements
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _shoulderController = TextEditingController();
  final _armLengthController = TextEditingController();
  final _shirtLengthController = TextEditingController();
  final _trouserLengthController = TextEditingController();
  final _trouserWaistController = TextEditingController();
  bool _usePreviousMeasurement = false;

  // Step 5: Amounts
  final _stitchingController = TextEditingController();
  final _materialController = TextEditingController();
  final _advanceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await DataService.getCustomers();
    setState(() => _customers = customers);
  }

  Future<void> _searchCustomers(String query) async {
    final customers =
        await DataService.getCustomers(search: query.isEmpty ? null : query);
    setState(() => _customers = customers);
  }

  Future<void> _loadPreviousMeasurement() async {
    if (_selectedCustomer == null || _selectedOrderType == null) return;
    final measurement = await DatabaseService.getLatestMeasurement(
        _selectedCustomer!.id!, _selectedOrderType!);
    if (measurement != null) {
      setState(() {
        _usePreviousMeasurement = true;
        _chestController.text = measurement.chest?.toString() ?? '';
        _waistController.text = measurement.waist?.toString() ?? '';
        _hipController.text = measurement.hip?.toString() ?? '';
        _shoulderController.text = measurement.shoulder?.toString() ?? '';
        _armLengthController.text = measurement.armLength?.toString() ?? '';
        _shirtLengthController.text = measurement.shirtLength?.toString() ?? '';
        _trouserLengthController.text =
            measurement.trouserLength?.toString() ?? '';
        _trouserWaistController.text =
            measurement.trouserWaist?.toString() ?? '';
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedCustomer == null) {
      _showSnack('Please select or add a customer');
      return;
    }
    if (_currentStep == 1 && _selectedOrderType == null) {
      _showSnack('Please select an order type');
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

      if (_currentStep == 3) {
        _loadPreviousMeasurement();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addNewCustomer() async {
    final name = _newNameController.text.trim();
    final phone = _newPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnack('Please enter name and phone');
      return;
    }

    final customer = Customer(name: name, phone: phone);
    final id = await DataService.insertCustomer(customer);

    final saved = customer.copyWith(
        id: id,
        serverId: DataService.lastCreatedCustomerServerId);
    setState(() {
      _selectedCustomer = saved;
      _addingNew = false;
      _newNameController.clear();
      _newPhoneController.clear();
    });

    Provider.of<AppProvider>(context, listen: false).refreshSyncCount();
    _nextStep();
  }

  Future<void> _saveOrder() async {
    final stitching =
        double.tryParse(_stitchingController.text.trim()) ?? 0;
    final material =
        double.tryParse(_materialController.text.trim()) ?? 0;
    final advance = double.tryParse(_advanceController.text.trim()) ?? 0;

    if (stitching <= 0) {
      _showSnack('Please enter stitching amount');
      return;
    }

    setState(() => _saving = true);

    try {
      // Save measurement
      final measurement = Measurement(
        customerId: _selectedCustomer!.id,
        customerServerId: _selectedCustomer!.serverId,
        orderType: _selectedOrderType!,
        chest: double.tryParse(_chestController.text),
        waist: double.tryParse(_waistController.text),
        hip: double.tryParse(_hipController.text),
        shoulder: double.tryParse(_shoulderController.text),
        armLength: double.tryParse(_armLengthController.text),
        shirtLength: double.tryParse(_shirtLengthController.text),
        trouserLength: double.tryParse(_trouserLengthController.text),
        trouserWaist: double.tryParse(_trouserWaistController.text),
      );
      final measurementId =
          await DataService.insertMeasurement(measurement);

      // Save order
      final total = stitching + material;
      final order = Order(
        customerId: _selectedCustomer!.id,
        customerServerId: _selectedCustomer!.serverId,
        customerName: _selectedCustomer!.name,
        customerPhone: _selectedCustomer!.phone,
        orderType: _selectedOrderType!,
        stitchingAmount: stitching,
        materialAmount: material,
        totalAmount: total,
        paidAmount: advance,
        balanceAmount: total - advance,
        designPhotoPath: _designPhotoPath,
        measurementId: measurementId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        dueDate: _dueDate,
      );
      final orderId = await DataService.insertOrder(order);

      // Save advance payment if given (only in offline mode — online mode
      // handles it via advancePayment field in the order API)
      if (advance > 0 && !DataService.isOnlineMode) {
        await DataService.insertPayment(
          _buildPayment(orderId, advance),
        );
      }

      if (!mounted) return;

      Provider.of<AppProvider>(context, listen: false).refreshSyncCount();

      // Show success
      _showSuccessDialog();
    } catch (e) {
      _showSnack('Error saving order: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  _buildPayment(int orderId, double amount) {
    return Payment(orderId: orderId, amount: amount, method: 'Cash');
  }

  void _showSuccessDialog() {
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
              const Text(
                'Order Saved!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'آرڈر محفوظ ہو گیا',
                style:
                    TextStyle(fontSize: 16, color: AppColors.textMedium),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedCustomer?.name} - $_selectedOrderType',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                ),
              ),
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

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customerSearchController.dispose();
    _newNameController.dispose();
    _newPhoneController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _shoulderController.dispose();
    _armLengthController.dispose();
    _shirtLengthController.dispose();
    _trouserLengthController.dispose();
    _trouserWaistController.dispose();
    _stitchingController.dispose();
    _materialController.dispose();
    _advanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order / نیا آرڈر'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          _buildProgressBar(),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCustomerStep(),
                _buildOrderTypeStep(),
                _buildPhotoStep(),
                _buildMeasurementStep(),
                _buildAmountsStep(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : (_currentStep == _totalSteps - 1 ? _saveOrder : _nextStep),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1
                          ? 'Save Order'
                          : 'Next',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Customer ───

  Widget _buildCustomerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Customer',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const Text('گاہک منتخب کریں',
              style: TextStyle(color: AppColors.textMedium)),
          const SizedBox(height: 16),

          if (_selectedCustomer != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedCustomer!.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_selectedCustomer!.phone,
                            style: const TextStyle(
                                color: AppColors.textMedium)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _selectedCustomer = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Search
          TextField(
            controller: _customerSearchController,
            onChanged: _searchCustomers,
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.person_add, color: AppColors.secondary),
                onPressed: () => setState(() => _addingNew = !_addingNew),
              ),
            ),
          ),

          if (_addingNew) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Customer',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newNameController,
                    decoration:
                        const InputDecoration(hintText: 'Customer Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPhoneController,
                    decoration: const InputDecoration(hintText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addNewCustomer,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add & Select'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Customer list
          ..._customers.map(
            (c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.phone),
              selected: _selectedCustomer?.id == c.id,
              selectedTileColor: AppColors.primary.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () => setState(() => _selectedCustomer = c),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Order Type ───

  Widget _buildOrderTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What to stitch?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const Text('کیا سلوانا ہے؟',
              style: TextStyle(color: AppColors.textMedium)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: OrderTypes.types.map((type) {
              final isSelected = _selectedOrderType == type['id'];
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedOrderType = type['id'] as String),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 36,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                      Text(
                        type['urdu'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.7)
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Photo ───

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Design Photo',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const Text('ڈیزائن کی تصویر',
              style: TextStyle(color: AppColors.textMedium)),
          const SizedBox(height: 8),
          const Text(
            'Take a photo of the design the customer wants',
            style: TextStyle(color: AppColors.textMedium, fontSize: 14),
          ),
          const SizedBox(height: 20),
          PhotoCaptureWidget(
            photoPath: _designPhotoPath,
            label: 'Tap to capture design',
            onPhotoCaptured: (path) =>
                setState(() => _designPhotoPath = path),
          ),
          const SizedBox(height: 16),
          Text(
            'You can skip this step if no photo is needed',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 4: Measurements ───

  Widget _buildMeasurementStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Measurements',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    Text('ناپ', style: TextStyle(color: AppColors.textMedium)),
                  ],
                ),
              ),
              if (_usePreviousMeasurement)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Previous loaded',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('All measurements in inches',
              style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 16),
          _measurementField('Chest / چھاتی', _chestController),
          _measurementField('Waist / کمر', _waistController),
          _measurementField('Hip / کولہا', _hipController),
          _measurementField('Shoulder / کندھا', _shoulderController),
          _measurementField('Arm Length / بازو', _armLengthController),
          _measurementField('Shirt Length / قمیض', _shirtLengthController),
          _measurementField(
              'Trouser Length / شلوار', _trouserLengthController),
          _measurementField(
              'Trouser Waist / شلوار کمر', _trouserWaistController),
        ],
      ),
    );
  }

  Widget _measurementField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '"',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.cardBg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 5: Amounts ───

  Widget _buildAmountsStep() {
    final stitching =
        double.tryParse(_stitchingController.text.trim()) ?? 0;
    final material =
        double.tryParse(_materialController.text.trim()) ?? 0;
    final total = stitching + material;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amounts',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const Text('رقم', style: TextStyle(color: AppColors.textMedium)),
          const SizedBox(height: 20),

          AmountInput(
            label: 'Stitching Amount / سلائی',
            controller: _stitchingController,
            required: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          AmountInput(
            label: 'Material Amount / کپڑا (optional)',
            controller: _materialController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Total display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total / کل',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  Helpers.formatCurrency(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AmountInput(
            label: 'Advance Payment / پیشگی (optional)',
            controller: _advanceController,
          ),
          const SizedBox(height: 16),

          // Due date
          GestureDetector(
            onTap: _pickDueDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Due Date / حوالگی تاریخ',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMedium)),
                      Text(
                        Helpers.formatDate(_dueDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, size: 18, color: AppColors.textLight),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
              labelText: 'Notes / نوٹس',
            ),
          ),
        ],
      ),
    );
  }
}

