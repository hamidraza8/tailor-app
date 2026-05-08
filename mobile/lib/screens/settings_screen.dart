import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlController = TextEditingController();
  bool _saving = false;
  bool _isOnlineMode = DataService.isOnlineMode;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = ApiConfig.baseUrl;
  }

  Future<void> _saveApiUrl() async {
    final url = _apiUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }

    setState(() => _saving = true);
    await AuthService.setApiUrl(url);
    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URL saved!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout?'),
        content: const Text(
            'Your local data will remain saved. You can login again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<AppProvider>(context, listen: false).clearUser();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                if (provider.user == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          (provider.user?['name'] as String? ?? '?')[0]
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.user?['name'] as String? ?? 'User',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              provider.user?['email'] as String? ?? '',
                              style: const TextStyle(
                                  color: AppColors.textMedium, fontSize: 13),
                            ),
                            Text(
                              provider.user?['role']?.toString() ?? '',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Data Mode
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOnlineMode
                    ? AppColors.success.withOpacity(0.08)
                    : AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOnlineMode ? AppColors.success : AppColors.warning,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOnlineMode ? Icons.cloud : Icons.cloud_off,
                        color: _isOnlineMode ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isOnlineMode ? 'Online Mode' : 'Offline Mode',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Switch(
                        value: _isOnlineMode,
                        activeColor: AppColors.success,
                        onChanged: (value) async {
                          await DataService.setMode(value);
                          setState(() => _isOnlineMode = value);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? 'Online mode: Data saved directly to server'
                                  : 'Offline mode: Data saved locally, synced later'),
                              backgroundColor:
                                  value ? AppColors.success : AppColors.warning,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isOnlineMode
                        ? 'All data is read from and saved directly to the server. Requires internet connection.'
                        : 'Data is saved locally and synced to the server when online.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // API URL
            const Text('Server URL',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text('The address of your backend server',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'http://your-server:3000/api',
                prefixIcon: Icon(Icons.link, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveApiUrl,
                child: Text(_saving ? 'Saving...' : 'Save URL'),
              ),
            ),
            const SizedBox(height: 32),

            // App info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('App Version',
                          style: TextStyle(color: AppColors.textMedium)),
                      Text('1.0.0',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Data Mode',
                          style: TextStyle(color: AppColors.textMedium)),
                      Text(_isOnlineMode ? 'Online (API)' : 'Offline (Local)',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                if (provider.user == null) return const SizedBox.shrink();
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text('Logout',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
