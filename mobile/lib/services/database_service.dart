import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/measurement.dart';
import '../models/payment.dart';
import '../models/asset.dart';
import '../models/inventory.dart';
import '../models/sync_item.dart';

/// Cross-platform database service using SharedPreferences.
/// Works on Web, Android, iOS - no native SQLite dependency.
class DatabaseService {
  static SharedPreferences? _prefs;
  static int _nextId = 1;

  static Future<SharedPreferences> get _db async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt('_next_id') ?? 1;
  }

  static int _generateId() {
    final id = _nextId++;
    _prefs?.setInt('_next_id', _nextId);
    return id;
  }

  // ─── Generic helpers ───

  static Future<List<Map<String, dynamic>>> _getTable(String table) async {
    final prefs = await _db;
    final raw = prefs.getString('table_$table');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _saveTable(
      String table, List<Map<String, dynamic>> rows) async {
    final prefs = await _db;
    await prefs.setString('table_$table', jsonEncode(rows));
  }

  static Future<int> _insert(String table, Map<String, dynamic> row) async {
    final rows = await _getTable(table);
    final id = _generateId();
    row['id'] = id;
    rows.add(row);
    await _saveTable(table, rows);
    return id;
  }

  static Future<void> _update(
      String table, int id, Map<String, dynamic> updates) async {
    final rows = await _getTable(table);
    final idx = rows.indexWhere((r) => r['id'] == id);
    if (idx >= 0) {
      rows[idx].addAll(updates);
      await _saveTable(table, rows);
    }
  }

  static Future<void> updateServerId(String table, int id, String serverId) async {
    await _update(table, id, {'server_id': serverId, 'synced': 1});
  }

  static Future<void> _delete(String table, int id) async {
    final rows = await _getTable(table);
    rows.removeWhere((r) => r['id'] == id);
    await _saveTable(table, rows);
  }

  // ─── Customers ───

  static Future<int> insertCustomer(Customer customer) async {
    final map = customer.toMap()..remove('id');
    return await _insert('customers', map);
  }

  static Future<List<Customer>> getCustomers({String? search}) async {
    final rows = await _getTable('customers');
    var filtered = rows;
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = rows
          .where((r) =>
              (r['name'] ?? '').toString().toLowerCase().contains(q) ||
              (r['phone'] ?? '').toString().contains(q))
          .toList();
    }
    filtered.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(b['name'] ?? ''));
    return filtered.map((m) => Customer.fromMap(m)).toList();
  }

  static Future<Customer?> getCustomerById(int id) async {
    final rows = await _getTable('customers');
    final match = rows.where((r) => r['id'] == id);
    if (match.isEmpty) return null;
    return Customer.fromMap(match.first);
  }

  static Future<void> updateCustomer(Customer customer) async {
    if (customer.id != null) {
      await _update('customers', customer.id!, customer.toMap());
    }
  }

  // ─── Orders ───

  static Future<int> insertOrder(Order order) async {
    final map = order.toMap()..remove('id');
    return await _insert('orders', map);
  }

  static Future<List<Order>> getOrders({String? status, String? date}) async {
    final rows = await _getTable('orders');
    var filtered = rows.where((r) => (r['is_deleted'] ?? 0) != 1).toList();
    if (status != null) {
      filtered = filtered.where((r) => r['status'] == status).toList();
    }
    if (date != null) {
      filtered = filtered
          .where((r) => (r['created_at'] ?? '').toString().startsWith(date))
          .toList();
    }
    filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return filtered.map((m) => Order.fromMap(m)).toList();
  }

  static Future<List<Order>> getTodayOrders() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getOrders(date: today);
  }

  static Future<List<Order>> getActiveOrders() async {
    final rows = await _getTable('orders');
    final active = rows.where((r) =>
        (r['is_deleted'] ?? 0) != 1 && r['status'] != 'Delivered').toList();
    active.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return active.map((m) => Order.fromMap(m)).toList();
  }

  static Future<Order?> getOrderById(int id) async {
    final rows = await _getTable('orders');
    final match = rows.where((r) => r['id'] == id && (r['is_deleted'] ?? 0) != 1);
    if (match.isEmpty) return null;
    return Order.fromMap(match.first);
  }

  static Future<void> softDeleteOrder(int id) async {
    await _update('orders', id, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()});
  }

  static Future<void> restoreOrder(int id) async {
    await _update('orders', id, {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()});
  }

  // ─── Upsert helpers for resync ───

  static Future<void> upsertOrderByServerId(Order order) async {
    final rows = await _getTable('orders');
    final idx = rows.indexWhere((r) => r['server_id'] == order.serverId);
    final map = order.toMap()..remove('id');
    map['is_deleted'] = 0;
    map['synced'] = 1;
    if (idx >= 0) {
      final existingId = rows[idx]['id'];
      map['id'] = existingId;
      rows[idx] = map;
      await _saveTable('orders', rows);
    } else {
      await _insert('orders', map);
    }
  }

  static Future<void> removeOrdersNotInServerIds(Set<String> serverIds) async {
    final rows = await _getTable('orders');
    // Only remove rows that have a server_id not in the set (server-deleted)
    // Keep rows with no server_id (local-only pending creates)
    final kept = rows.where((r) {
      final sid = r['server_id'] as String?;
      if (sid == null || sid.isEmpty) return true; // local-only, keep
      return serverIds.contains(sid); // keep if server still has it
    }).toList();
    await _saveTable('orders', kept);
  }

  static Future<void> upsertCustomerByServerId(Customer customer) async {
    final rows = await _getTable('customers');
    final idx = rows.indexWhere((r) => r['server_id'] == customer.serverId);
    final map = customer.toMap()..remove('id');
    map['synced'] = 1;
    if (idx >= 0) {
      map['id'] = rows[idx]['id'];
      rows[idx] = map;
      await _saveTable('customers', rows);
    } else {
      await _insert('customers', map);
    }
  }

  static Future<void> upsertPaymentByServerId(Payment payment) async {
    final rows = await _getTable('payments');
    final idx = rows.indexWhere((r) => r['server_id'] == payment.serverId);
    final map = payment.toMap()..remove('id');
    map['synced'] = 1;
    // Resolve local order_id from order_server_id if missing
    if ((map['order_id'] == null) && payment.orderServerId != null) {
      final orderRows = await _getTable('orders');
      final orderRow = orderRows.where((r) => r['server_id'] == payment.orderServerId).firstOrNull;
      if (orderRow != null) map['order_id'] = orderRow['id'];
    }
    if (idx >= 0) {
      map['id'] = rows[idx]['id'];
      rows[idx] = map;
      await _saveTable('payments', rows);
    } else {
      await _insert('payments', map);
    }
  }

  static Future<void> upsertAssetByServerId(Asset asset) async {
    final rows = await _getTable('assets');
    final idx = rows.indexWhere((r) => r['server_id'] == asset.serverId);
    final map = asset.toMap()..remove('id');
    map['synced'] = 1;
    if (idx >= 0) {
      map['id'] = rows[idx]['id'];
      rows[idx] = map;
      await _saveTable('assets', rows);
    } else {
      await _insert('assets', map);
    }
  }

  static Future<void> upsertInventoryByServerId(InventoryTransaction tx) async {
    final rows = await _getTable('inventory_transactions');
    final idx = rows.indexWhere((r) => r['server_id'] == tx.serverId);
    final map = tx.toMap()..remove('id');
    map['synced'] = 1;
    if (idx >= 0) {
      map['id'] = rows[idx]['id'];
      rows[idx] = map;
      await _saveTable('inventory_transactions', rows);
    } else {
      await _insert('inventory_transactions', map);
    }
  }

  static Future<void> updateOrder(Order order) async {
    if (order.id != null) {
      await _update('orders', order.id!, order.toMap());
    }
  }

  static Future<void> updateOrderStatus(int id, String status) async {
    await _update(
        'orders', id, {'status': status, 'updated_at': DateTime.now().toIso8601String()});
  }

  static Future<List<Order>> getOrdersByCustomer(int customerId) async {
    final rows = await _getTable('orders');
    final filtered =
        rows.where((r) => r['customer_id'] == customerId).toList();
    filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return filtered.map((m) => Order.fromMap(m)).toList();
  }

  static Future<List<Order>> getOrdersWithBalance() async {
    final rows = await _getTable('orders');
    final filtered = rows
        .where((r) =>
            (r['is_deleted'] ?? 0) != 1 &&
            (r['balance_amount'] ?? 0) > 0 &&
            r['status'] != 'Delivered')
        .toList();
    filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return filtered.map((m) => Order.fromMap(m)).toList();
  }

  // ─── Measurements ───

  static Future<int> insertMeasurement(Measurement measurement) async {
    final map = measurement.toMap()..remove('id');
    return await _insert('measurements', map);
  }

  static Future<List<Measurement>> getMeasurementsByCustomer(
      int customerId) async {
    final rows = await _getTable('measurements');
    final filtered =
        rows.where((r) => r['customer_id'] == customerId).toList();
    filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return filtered.map((m) => Measurement.fromMap(m)).toList();
  }

  static Future<Measurement?> getLatestMeasurement(
      int customerId, String orderType) async {
    final rows = await _getTable('measurements');
    final filtered = rows
        .where((r) =>
            r['customer_id'] == customerId && r['order_type'] == orderType)
        .toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return Measurement.fromMap(filtered.first);
  }

  // ─── Payments ───

  static Future<int> insertPayment(Payment payment) async {
    final map = payment.toMap()..remove('id');
    final paymentId = await _insert('payments', map);

    // Update order paid and balance amounts
    if (payment.orderId != null) {
      final order = await getOrderById(payment.orderId!);
      if (order != null) {
        final newPaid = order.paidAmount + payment.amount;
        final newBalance = order.totalAmount - newPaid;
        await _update('orders', order.id!, {
          'paid_amount': newPaid,
          'balance_amount': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    return paymentId;
  }

  static Future<List<Payment>> getPaymentsByOrder(int orderId) async {
    final rows = await _getTable('payments');
    final filtered = rows.where((r) => r['order_id'] == orderId).toList();
    filtered.sort((a, b) => (b['paid_at'] ?? '').compareTo(a['paid_at'] ?? ''));
    return filtered.map((m) => Payment.fromMap(m)).toList();
  }

  static Future<void> deletePayment(Payment payment) async {
    if (payment.id == null) return;
    await _delete('payments', payment.id!);
    // Reverse the payment amount on the order
    if (payment.orderId != null) {
      final order = await getOrderById(payment.orderId!);
      if (order != null) {
        final newPaid = (order.paidAmount - payment.amount).clamp(0, double.infinity);
        final newBalance = order.totalAmount - newPaid;
        await _update('orders', order.id!, {
          'paid_amount': newPaid,
          'balance_amount': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  static Future<List<Payment>> getAllPayments() async {
    final rows = await _getTable('payments');
    rows.sort((a, b) => (b['paid_at'] ?? '').compareTo(a['paid_at'] ?? ''));
    return rows.map((m) => Payment.fromMap(m)).toList();
  }

  // ─── Assets ───

  static Future<int> insertAsset(Asset asset) async {
    final map = asset.toMap()..remove('id');
    return await _insert('assets', map);
  }

  static Future<List<Asset>> getAssets() async {
    final rows = await _getTable('assets');
    rows.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return rows.map((m) => Asset.fromMap(m)).toList();
  }

  static Future<void> updateAssetStatus(int id, String status) async {
    await _update('assets', id, {'status': status});
  }

  // ─── Inventory ───

  static Future<int> insertInventoryTransaction(
      InventoryTransaction transaction) async {
    final map = transaction.toMap()..remove('id');
    return await _insert('inventory_transactions', map);
  }

  static Future<List<InventoryTransaction>> getInventoryTransactions() async {
    final rows = await _getTable('inventory_transactions');
    rows.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return rows.map((m) => InventoryTransaction.fromMap(m)).toList();
  }

  static Future<void> updateInventoryStatus(int id, String status) async {
    await _update('inventory_transactions', id, {'status': status});
  }

  static Future<void> deleteInventoryTransaction(int id) async {
    await _delete('inventory_transactions', id);
  }

  // ─── Sync Queue ───

  static Future<int> addToSyncQueue(SyncItem item) async {
    final map = item.toMap()..remove('id');
    return await _insert('sync_queue', map);
  }

  static Future<List<SyncItem>> getPendingSyncItems({bool includeExhausted = false}) async {
    final rows = await _getTable('sync_queue');
    final filtered = rows.where((r) {
      if (r['status'] != 'pending') return false;
      if (!includeExhausted && (r['retry_count'] ?? 0) >= 5) return false;
      return true;
    }).toList();
    filtered.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
    return filtered.map((m) => SyncItem.fromMap(m)).toList();
  }

  /// Reset retry count for all stuck items so they can be retried
  static Future<void> resetRetryCountsForPending() async {
    final rows = await _getTable('sync_queue');
    bool changed = false;
    for (final row in rows) {
      if (row['status'] == 'pending' && (row['retry_count'] ?? 0) >= 5) {
        row['retry_count'] = 0;
        row['error_message'] = null;
        changed = true;
      }
    }
    if (changed) await _saveTable('sync_queue', rows);
  }

  static Future<int> getPendingSyncCount() async {
    final rows = await _getTable('sync_queue');
    return rows.where((r) => r['status'] == 'pending' && (r['retry_count'] ?? 0) < 5).length;
  }

  static Future<void> updateSyncItemStatus(int id, String status,
      {String? errorMessage}) async {
    final updates = <String, dynamic>{'status': status};
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }
    if (status == 'pending') {
      // Increment retry count
      final rows = await _getTable('sync_queue');
      final idx = rows.indexWhere((r) => r['id'] == id);
      if (idx >= 0) {
        rows[idx]['retry_count'] = (rows[idx]['retry_count'] ?? 0) + 1;
        rows[idx]['status'] = status;
        if (errorMessage != null) rows[idx]['error_message'] = errorMessage;
        await _saveTable('sync_queue', rows);
      }
    } else {
      await _update('sync_queue', id, updates);
    }
  }

  /// Returns raw rows from any table that have no server_id set yet.
  static Future<List<Map<String, dynamic>>> getUnsyncedRows(String table) async {
    final rows = await _getTable(table);
    return rows.where((r) {
      final sid = r['server_id'] as String?;
      return sid == null || sid.isEmpty;
    }).toList();
  }

  static Future<bool> isSyncItemExhausted(int id) async {
    final rows = await _getTable('sync_queue');
    final match = rows.where((r) => r['id'] == id);
    if (match.isEmpty) return false;
    return (match.first['retry_count'] ?? 0) >= 5;
  }

  static Future<void> removeSyncItem(int id) async {
    await _delete('sync_queue', id);
  }

  static Future<List<SyncItem>> getAllSyncItems() async {
    final rows = await _getTable('sync_queue');
    rows.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return rows.map((m) => SyncItem.fromMap(m)).toList();
  }

  // ─── Local Files ───

  static Future<void> addLocalFile(
      String entityType, int entityId, String filePath) async {
    await _insert('local_files', {
      'entity_type': entityType,
      'entity_id': entityId,
      'file_path': filePath,
      'uploaded': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> markFileUploaded(int id, String remoteUrl) async {
    await _update('local_files', id, {'uploaded': 1, 'remote_url': remoteUrl});
  }
}
