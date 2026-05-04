import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class AddPartnerScreen extends StatefulWidget {
  const AddPartnerScreen({super.key});

  @override
  State<AddPartnerScreen> createState() => _AddPartnerScreenState();
}

class _AddPartnerScreenState extends State<AddPartnerScreen> {
  final _formKey = GlobalKey<FormState>();

  // User fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Partner fields
  double _profitShare = 50;
  double _labourShare = 35;
  final _notesController = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final online = await SyncService.isOnline();

    if (online) {
      // Online: direct two-step API call
      final userResult = await ApiService.post('/users', {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'role': 'Partner',
      });

      if (!mounted) return;

      if (userResult['success'] != true) {
        setState(() => _saving = false);
        _showSnack(userResult['message']?.toString() ?? 'Failed to create user');
        return;
      }

      final userId = userResult['id']?.toString() ?? userResult['data']?['id']?.toString();
      if (userId == null) {
        setState(() => _saving = false);
        _showSnack('Could not get user ID from response');
        return;
      }

      final partnerResult = await ApiService.post('/partners', {
        'userId': userId,
        'profitSharePercentage': _profitShare,
        'labourSharePercentage': _labourShare,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });

      if (!mounted) return;
      setState(() => _saving = false);

      if (partnerResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partner added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showSnack(partnerResult['message']?.toString() ?? 'Failed to create partner');
      }
    } else {
      // Offline: queue via sync
      await SyncService.addToQueue(
        entityType: 'partner',
        entityId: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        action: 'create',
        payload: {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          'profitSharePercentage': _profitShare,
          'labourSharePercentage': _labourShare,
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner saved offline — will sync when online'),
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
        title: const Text('Add Business Partner'),
        backgroundColor: AppColors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Personal Info
              _sectionHeader(Icons.person, 'Personal Information'),
              const SizedBox(height: 12),

              _label('Full Name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. Syed Raza'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _label('Phone Number'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '03001234567'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _label('Email'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'partner@example.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _label('Login Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Minimum 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Section: Partnership Terms
              _sectionHeader(Icons.handshake, 'Partnership Terms'),
              const SizedBox(height: 16),

              _label('Profit Share: ${_profitShare.toStringAsFixed(0)}%'),
              Slider(
                value: _profitShare,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.blue,
                label: '${_profitShare.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _profitShare = v),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share of net profit distributed to this partner',
                style: TextStyle(fontSize: 11, color: AppColors.textMedium),
              ),
              const SizedBox(height: 16),

              _label('Labour Share: ${_labourShare.toStringAsFixed(0)}%'),
              Slider(
                value: _labourShare,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.green,
                label: '${_labourShare.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _labourShare = v),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share of stitching revenue kept as labour cost (0% for investor)',
                style: TextStyle(fontSize: 11, color: AppColors.textMedium),
              ),
              const SizedBox(height: 16),

              _label('Notes (optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Investor partner, silent partner...'),
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
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(
                    _saving ? 'Creating...' : 'Add Partner',
                    style: const TextStyle(fontSize: 16),
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

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
    );
  }
}
