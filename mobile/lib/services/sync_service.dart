import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/sync_item.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/asset.dart';
import '../models/inventory.dart';
import 'database_service.dart';
import 'api_service.dart';

class SyncService {
  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result is List) {
        return !(result as List).contains(ConnectivityResult.none);
      }
      return result != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  static Future<void> addToQueue({
    required String entityType,
    required int entityId,
    required String action,
    Map<String, dynamic>? payload,
    String? filePath,
  }) async {
    final item = SyncItem(
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload != null ? jsonEncode(payload) : null,
      filePath: filePath,
    );
    await DatabaseService.addToSyncQueue(item);
  }

  static Future<int> getPendingCount() async {
    return await DatabaseService.getPendingSyncCount();
  }

  static Future<Map<String, dynamic>> processQueue({bool forceRetry = false}) async {
    final online = await isOnline();
    if (!online) {
      return {'success': false, 'message': 'No internet connection'};
    }

    if (forceRetry) {
      await DatabaseService.resetRetryCountsForPending();
    }

    final pendingItems = await DatabaseService.getPendingSyncItems(includeExhausted: forceRetry);
    int synced = 0;
    int failed = 0;

    for (final item in pendingItems) {
      try {
        final result = await _processSyncItem(item);
        if (result) {
          await DatabaseService.updateSyncItemStatus(item.id!, 'completed');
          synced++;
        } else {
          await DatabaseService.updateSyncItemStatus(item.id!, 'pending',
              errorMessage: 'Sync failed');
          failed++;
        }
      } catch (e) {
        await DatabaseService.updateSyncItemStatus(item.id!, 'pending',
            errorMessage: e.toString());
        // If a delete-order just exhausted its retries, restore it locally
        if (item.action == 'delete' && item.entityType.toLowerCase() == 'order') {
          final exhausted = await DatabaseService.isSyncItemExhausted(item.id!);
          if (exhausted) {
            await DatabaseService.restoreOrder(item.entityId);
          }
        }
        failed++;
      }
    }

    return {
      'success': true,
      'synced': synced,
      'failed': failed,
      'total': pendingItems.length,
    };
  }

  static Future<bool> _processSyncItem(SyncItem item) async {
    Map<String, dynamic>? payload;
    if (item.payload != null) {
      payload = jsonDecode(item.payload!) as Map<String, dynamic>;
    }

    // Use the sync/push endpoint which handles all entity types
    // This avoids needing to match each individual endpoint's DTO format
    final pushPayload = {
      'items': [
        {
          'entityType': item.entityType,
          'operation': item.action,
          'localId': _uuidFromInt(item.entityId),
          'payloadJson': item.payload ?? '{}',
          'fileRefs': <String>[],
        }
      ]
    };

    final result = await ApiService.post('/sync/push', pushPayload);

    if (result['success'] == true) {
      // Check individual item result
      final results = result['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final itemResult = results[0] as Map<String, dynamic>;
        if (itemResult['success'] != true) {
          // Store the server error so user can see it
          final error = itemResult['error']?.toString() ?? 'Unknown server error';
          throw Exception(error);
        }
        // Save server ID back to local entity
        final serverId = itemResult['serverId']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          await _saveServerId(item.entityType, item.entityId, serverId);
        }
        return true;
      }
      return true;
    }
    // Store the API error message
    final msg = result['message']?.toString() ?? 'API call failed';
    throw Exception(msg);
  }

  static Future<void> _saveServerId(String entityType, int entityId, String serverId) async {
    const tableMap = {
      'customer': 'customers',
      'order': 'orders',
      'payment': 'payments',
      'asset': 'assets',
      'inventory': 'inventory_transactions',
    };
    final table = tableMap[entityType.toLowerCase()];
    if (table != null) {
      await DatabaseService.updateServerId(table, entityId, serverId);
    }
  }

  /// Convert local int ID to a UUID-like string for the sync endpoint
  static String _uuidFromInt(int id) {
    final hex = id.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-0000-0000-$hex';
  }

  /// Full resync: push all pending local changes first, then pull all server
  /// records and upsert into local storage.
  static Future<Map<String, dynamic>> resyncAll() async {
    final online = await isOnline();
    if (!online) return {'success': false, 'message': 'No internet connection'};

    try {
      // Step 1: Re-queue any local records without server_id that aren't
      // already in the sync queue (handles cleared queue scenario)
      await _requeueUnsynced();

      // Step 2: Push all pending local changes
      await processQueue(forceRetry: true);

      // Step 2: Pull everything from the server
      final result = await ApiService.get('/sync/pull?lastSyncAt=2000-01-01T00:00:00Z');
      if (result['success'] != true) {
        return {'success': false, 'message': result['message'] ?? 'Pull failed'};
      }

      final rawItems = result['items'] as List<dynamic>? ?? [];

      // Group by entity type
      final Map<String, List<Map<String, dynamic>>> byType = {};
      for (final raw in rawItems) {
        final item = raw as Map<String, dynamic>;
        final type = (item['entityType'] as String? ?? item['entity_type'] as String? ?? '').toLowerCase();
        byType.putIfAbsent(type, () => []).add(item);
      }

      // Upsert each type
      await _upsertOrders(byType['order'] ?? []);
      await _upsertCustomers(byType['customer'] ?? []);
      await _upsertPayments(byType['payment'] ?? []);
      await _upsertAssets(byType['asset'] ?? []);
      await _upsertInventory(byType['inventory'] ?? []);

      return {
        'success': true,
        'total': rawItems.length,
        'orders': (byType['order'] ?? []).length,
        'customers': (byType['customer'] ?? []).length,
        'payments': (byType['payment'] ?? []).length,
        'assets': (byType['asset'] ?? []).length,
        'inventory': (byType['inventory'] ?? []).length,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Scan local tables and re-queue any records without a server_id that
  /// aren't already in the pending sync queue.
  static Future<void> _requeueUnsynced() async {
    final existingQueue = await DatabaseService.getAllSyncItems();
    // Build a set of already-queued local IDs per entity type
    final Map<String, Set<int>> queued = {};
    for (final item in existingQueue) {
      if (item.status == 'pending' || item.status == 'completed') continue;
      queued.putIfAbsent(item.entityType, () => {}).add(item.entityId);
    }
    // Also include pending items so we don't double-queue
    for (final item in existingQueue.where((i) => i.status == 'pending')) {
      queued.putIfAbsent(item.entityType, () => {}).add(item.entityId);
    }

    await _requeueTable('orders', 'order', queued, (row) => Order.fromMap(row).toJson());
    await _requeueTable('customers', 'customer', queued, (row) => Customer.fromMap(row).toJson());
    await _requeueTable('payments', 'payment', queued, (row) => Payment.fromMap(row).toJson());
    await _requeueTable('assets', 'asset', queued, (row) => Asset.fromMap(row).toJson());
    await _requeueTable('inventory_transactions', 'inventory', queued,
        (row) => InventoryTransaction.fromMap(row).toJson());
  }

  static Future<void> _requeueTable(
    String table,
    String entityType,
    Map<String, Set<int>> queued,
    Map<String, dynamic> Function(Map<String, dynamic> row) toJson,
  ) async {
    final rows = await DatabaseService.getUnsyncedRows(table);
    final alreadyQueued = queued[entityType] ?? {};
    for (final row in rows) {
      final localId = row['id'] as int?;
      if (localId == null || alreadyQueued.contains(localId)) continue;
      await addToQueue(
        entityType: entityType,
        entityId: localId,
        action: 'create',
        payload: toJson(row),
      );
    }
  }

  static Future<void> _upsertOrders(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final serverIds = <String>{};
    for (final item in items) {
      final data = _parseData(item['payloadJson']);
      if (data == null) continue;
      final serverId = data['id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      serverIds.add(serverId);

      final order = Order(
        serverId: serverId,
        customerName: data['customer']?['name'] as String? ?? data['customerName'] as String? ?? '',
        customerPhone: data['customer']?['phone'] as String? ?? data['customerPhone'] as String? ?? '',
        orderType: data['orderType']?.toString() ?? 'Other',
        status: data['status']?.toString() ?? 'Received',
        stitchingAmount: (data['stitchingAmount'] as num?)?.toDouble() ?? 0,
        materialAmount: (data['materialAmount'] as num?)?.toDouble() ?? 0,
        paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
        notes: data['designNotes'] as String?,
        dueDate: data['dueDate'] != null ? DateTime.tryParse(data['dueDate'].toString()) : null,
        createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt'].toString()) : null,
        synced: true,
      );
      await DatabaseService.upsertOrderByServerId(order);
    }
    // Remove local orders whose server counterpart is gone (deleted on server)
    await DatabaseService.removeOrdersNotInServerIds(serverIds);
  }

  static Future<void> _upsertCustomers(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      final data = _parseData(item['payloadJson']);
      if (data == null) continue;
      final serverId = data['id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      final customer = Customer(
        serverId: serverId,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        email: data['email'] as String?,
        address: data['address'] as String?,
        notes: data['notes'] as String?,
        synced: true,
      );
      await DatabaseService.upsertCustomerByServerId(customer);
    }
  }

  static Future<void> _upsertPayments(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      final data = _parseData(item['payloadJson']);
      if (data == null) continue;
      final serverId = data['id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      final payment = Payment(
        serverId: serverId,
        orderServerId: data['orderId']?.toString(),
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        method: _parsePaymentMethod(data['method']),
        notes: data['notes'] as String?,
        paidAt: data['paymentDate'] != null ? DateTime.tryParse(data['paymentDate'].toString())
            : data['paidAt'] != null ? DateTime.tryParse(data['paidAt'].toString()) : null,
        synced: true,
      );
      await DatabaseService.upsertPaymentByServerId(payment);
    }
  }

  static Future<void> _upsertAssets(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      final data = _parseData(item['payloadJson']);
      if (data == null) continue;
      final serverId = data['id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      final asset = Asset(
        serverId: serverId,
        name: data['name'] as String? ?? '',
        type: data['assetType'] as String? ?? '',
        quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        unitValue: (data['unitValue'] as num?)?.toDouble() ?? 0,
        status: _parseApprovalStatus(data['approvalStatus']),
        notes: data['notes'] as String?,
        synced: true,
      );
      await DatabaseService.upsertAssetByServerId(asset);
    }
  }

  static Future<void> _upsertInventory(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      final data = _parseData(item['payloadJson']);
      if (data == null) continue;
      final serverId = data['id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      final tx = InventoryTransaction(
        serverId: serverId,
        itemName: data['inventoryItem']?['name'] as String? ?? 'Unknown',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        unit: data['inventoryItem']?['unit'] as String?,
        costPerUnit: (data['unitCost'] as num?)?.toDouble() ?? 0,
        status: _parseApprovalStatus(data['approvalStatus']),
        notes: data['notes'] as String?,
        synced: true,
      );
      await DatabaseService.upsertInventoryByServerId(tx);
    }
  }

  static String _parsePaymentMethod(dynamic raw) {
    if (raw == null) return 'Cash';
    final s = raw.toString();
    const map = {'0': 'Cash', '1': 'Bank Transfer', '2': 'EasyPaisa', '3': 'JazzCash', '4': 'Other'};
    return map[s] ?? s;
  }

  static String _parseApprovalStatus(dynamic raw) {
    if (raw == null) return 'Pending';
    final s = raw.toString();
    const map = {'0': 'Pending', '1': 'Approved', '2': 'Rejected'};
    return map[s] ?? s;
  }

  static Map<String, dynamic>? _parseData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> pullUpdates() async {
    final online = await isOnline();
    if (!online) return;

    try {
      final ordersResult = await ApiService.get('/orders?limit=50');
      if (ordersResult['success'] == true && ordersResult['data'] != null) {
        // Process and store updates
      }
    } catch (e) {
      // Silently fail
    }
  }
}
