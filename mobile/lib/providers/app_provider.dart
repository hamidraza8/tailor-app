import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class AppProvider extends ChangeNotifier {
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  Map<String, dynamic>? _user;
  Timer? _syncTimer;
  Timer? _connectivityTimer;

  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isSyncing => _isSyncing;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check connectivity by pinging server
    _isOnline = await SyncService.isOnline();

    // Load user
    _user = await AuthService.getUser();

    // Load pending sync count
    await refreshSyncCount();

    // Periodically check connectivity and sync (every 30 seconds)
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final wasOnline = _isOnline;
      _isOnline = await SyncService.isOnline();
      if (_isOnline != wasOnline) notifyListeners();
      if (_isOnline) syncNow();
    });

    // Force retry sync every 2 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      syncNow(forceRetry: true);
    });

    notifyListeners();
  }

  Future<void> refreshSyncCount() async {
    try {
      _pendingSyncCount = await SyncService.getPendingCount();
    } catch (_) {
      _pendingSyncCount = 0;
    }
    notifyListeners();
  }

  Future<void> syncNow({bool forceRetry = false}) async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await SyncService.processQueue(forceRetry: forceRetry);
      await refreshSyncCount();
    } catch (e) {
      // Silently handle sync errors
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> setUser(Map<String, dynamic> user) async {
    _user = user;
    notifyListeners();
  }

  Future<void> clearUser() async {
    _user = null;
    await AuthService.logout();
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }
}
