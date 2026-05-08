import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../widgets/photo_capture_widget.dart';
import '../widgets/amount_input.dart';
import '../utils/constants.dart';

class AddInventoryScreen extends StatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  String? _receiptPhotoPath;
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'meters');
  final _costPerUnitController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  final List<String> _units = ['meters', 'yards', 'pieces', 'rolls', 'kg', 'dozen'];

  Future<void> _save() async {
    final name = _itemNameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter item name');
      return;
    }
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      _showSnack('Please enter quantity');
      return;
    }
    final cost = double.tryParse(_costPerUnitController.text.trim()) ?? 0;
    if (cost <= 0) {
      _showSnack('Please enter cost per unit');
      return;
    }

    setState(() => _saving = true);

    try {
      final transaction = InventoryTransaction(
        itemName: name,
        quantity: qty,
        unit: _unitController.text.trim(),
        costPerUnit: cost,
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        receiptPhotoPath: _receiptPhotoPath,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await DataService.insertInventoryTransaction(transaction);

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
              const Text('Inventory Saved!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('سامان محفوظ ہو گیا',
                  style: TextStyle(color: AppColors.textMedium)),
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
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costPerUnitController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Inventory / سامان'),
        backgroundColor: AppColors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt photo
            PhotoCaptureWidget(
              photoPath: _receiptPhotoPath,
              label: 'Take receipt photo (optional)',
              onPhotoCaptured: (path) =>
                  setState(() => _receiptPhotoPath = path),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'OCR auto-fill coming soon!',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Item name
            TextField(
              controller: _itemNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g. Lawn Fabric, Thread, Buttons',
                prefixIcon: Icon(Icons.inventory_2, color: AppColors.purple),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity + Unit
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unitController.text,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _units
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _unitController.text = val;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cost per unit
            AmountInput(
              label: 'Cost per unit',
              controller: _costPerUnitController,
            ),
            const SizedBox(height: 16),

            // Supplier
            TextField(
              controller: _supplierController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Supplier (optional)',
                hintText: 'Shop or supplier name',
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 32),

            // Save
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple),
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save as Pending',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
