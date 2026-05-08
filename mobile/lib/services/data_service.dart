import '../models/order.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/asset.dart';
import '../models/inventory.dart';
import '../models/measurement.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Routes data operations to either API (online mode) or local DB + sync (offline mode).
class DataService {
  static const String _modeKey = 'data_mode';
  static bool _isOnlineMode = true;

  static bool get isOnlineMode => _isOnlineMode;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnlineMode = prefs.getBool(_modeKey) ?? true;
  }

  static Future<void> setMode(bool online) async {
    _isOnlineMode = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modeKey, online);
  }

  // ─── Orders ───

  static Future<List<Order>> getOrders() async {
    if (_isOnlineMode) {
      final result = await ApiService.get('/orders');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getOrders();
  }

  static Future<List<Order>> getTodayOrders() async {
    if (_isOnlineMode) {
      final result = await ApiService.get('/orders/today');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getTodayOrders();
  }

  static Future<List<Order>> getActiveOrders() async {
    if (_isOnlineMode) {
      final orders = await getOrders();
      return orders.where((o) =>
          o.status != 'Delivered' && o.status != 'Cancelled').toList();
    }
    return DatabaseService.getActiveOrders();
  }

  static Future<List<Order>> getOrdersWithBalance() async {
    if (_isOnlineMode) {
      final orders = await getOrders();
      return orders.where((o) => o.balanceAmount > 0).toList();
    }
    return DatabaseService.getOrdersWithBalance();
  }

  static Future<Order?> getOrderById(int id) async {
    return DatabaseService.getOrderById(id);
  }

  /// In online mode, finds/creates customer first, then creates order via API.
  static Future<int> insertOrder(Order order) async {
    if (_isOnlineMode) {
      // Step 1: Find or create customer
      String? customerId = order.customerServerId;
      if (customerId == null && order.customerName != null) {
        customerId = await _findOrCreateCustomer(
            order.customerName!, order.customerPhone ?? '');
      }
      if (customerId == null) {
        throw Exception('Could not find or create customer');
      }

      // Step 2: Create order with correct API payload
      final apiPayload = {
        'customerId': customerId,
        'orderType': order.orderType,
        'stitchingAmount': order.stitchingAmount,
        'materialAmount': order.materialAmount,
        'discount': 0,
        'dueDate': order.dueDate?.toUtc().toIso8601String(),
        'designNotes': order.notes,
        'isUrgent': false,
        'advancePayment': order.paidAmount > 0 ? order.paidAmount : null,
      };

      final result = await ApiService.post('/orders', apiPayload);
      if (result['success'] == true) {
        final localId = await DatabaseService.insertOrder(order.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? result['error'] ?? 'Failed to create order');
    }
    final id = await DatabaseService.insertOrder(order);
    await SyncService.addToQueue(
        entityType: 'order', entityId: id, action: 'create', payload: order.toJson());
    return id;
  }

  /// Finds existing customer by name+phone or creates a new one. Returns server GUID.
  static Future<String?> _findOrCreateCustomer(String name, String phone) async {
    // Try to find existing customer
    final searchResult = await ApiService.get('/customers');
    if (searchResult['success'] == true && searchResult['data'] is List) {
      final customers = searchResult['data'] as List;
      for (final c in customers) {
        final map = c as Map<String, dynamic>;
        if (map['name'] == name && map['phone'] == phone) {
          return map['id']?.toString();
        }
      }
    }

    // Create new customer
    final createResult = await ApiService.post('/customers', {
      'name': name,
      'phone': phone,
    });
    if (createResult['success'] == true) {
      return createResult['id']?.toString();
    }
    return null;
  }

  // ─── Customers ───

  static Future<List<Customer>> getCustomers({String? search}) async {
    if (_isOnlineMode) {
      final endpoint = search != null ? '/customers?search=$search' : '/customers';
      final result = await ApiService.get(endpoint);
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getCustomers(search: search);
  }

  static Future<int> insertCustomer(Customer customer) async {
    if (_isOnlineMode) {
      final result = await ApiService.post('/customers', {
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'notes': customer.notes,
      });
      if (result['success'] == true) {
        final localId = await DatabaseService.insertCustomer(customer.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to create customer');
    }
    final id = await DatabaseService.insertCustomer(customer);
    await SyncService.addToQueue(
        entityType: 'customer', entityId: id, action: 'create', payload: customer.toJson());
    return id;
  }

  // ─── Payments ───

  static Future<List<Payment>> getAllPayments() async {
    if (_isOnlineMode) {
      final result = await ApiService.get('/payments');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Payment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getAllPayments();
  }

  static Future<List<Payment>> getPaymentsByOrder(int orderId) async {
    return DatabaseService.getPaymentsByOrder(orderId);
  }

  static Future<int> insertPayment(Payment payment) async {
    if (_isOnlineMode) {
      final result = await ApiService.post('/payments', {
        'orderId': payment.orderServerId ?? payment.orderId?.toString(),
        'amount': payment.amount,
        'method': payment.method,
        'paymentDate': payment.paidAt.toUtc().toIso8601String(),
        'notes': payment.notes,
      });
      if (result['success'] == true) {
        final localId = await DatabaseService.insertPayment(payment.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to record payment');
    }
    final id = await DatabaseService.insertPayment(payment);
    await SyncService.addToQueue(
        entityType: 'payment', entityId: id, action: 'create', payload: payment.toJson());
    return id;
  }

  // ─── Inventory ───

  static Future<List<InventoryTransaction>> getInventoryTransactions() async {
    if (_isOnlineMode) {
      final result = await ApiService.get('/inventory');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => InventoryTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getInventoryTransactions();
  }

  static Future<int> insertInventoryTransaction(InventoryTransaction txn) async {
    if (_isOnlineMode) {
      final result = await ApiService.post('/inventory', {
        'itemName': txn.itemName,
        'type': txn.type,
        'quantity': txn.quantity,
        'unit': txn.unit,
        'costPerUnit': txn.costPerUnit,
        'totalCost': txn.totalCost,
        'supplier': txn.supplier,
        'notes': txn.notes,
      });
      if (result['success'] == true) {
        final localId = await DatabaseService.insertInventoryTransaction(txn.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to add inventory');
    }
    final id = await DatabaseService.insertInventoryTransaction(txn);
    await SyncService.addToQueue(
        entityType: 'inventory', entityId: id, action: 'create', payload: txn.toJson());
    return id;
  }

  // ─── Assets ───

  static Future<List<Asset>> getAssets() async {
    if (_isOnlineMode) {
      final result = await ApiService.get('/assets');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Asset.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    return DatabaseService.getAssets();
  }

  static Future<int> insertAsset(Asset asset) async {
    if (_isOnlineMode) {
      final result = await ApiService.post('/assets', {
        'name': asset.name,
        'assetType': asset.type,
        'quantity': asset.quantity,
        'unitValue': asset.unitValue,
        'ownership': 'Business',
        'notes': asset.notes,
      });
      if (result['success'] == true) {
        final localId = await DatabaseService.insertAsset(asset.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to add asset');
    }
    final id = await DatabaseService.insertAsset(asset);
    await SyncService.addToQueue(
        entityType: 'asset', entityId: id, action: 'create', payload: asset.toJson());
    return id;
  }

  // ─── Measurements ───

  static Future<int> insertMeasurement(Measurement measurement) async {
    if (_isOnlineMode) {
      return DatabaseService.insertMeasurement(measurement);
    }
    final id = await DatabaseService.insertMeasurement(measurement);
    await SyncService.addToQueue(
        entityType: 'measurement', entityId: id, action: 'create', payload: measurement.toMap());
    return id;
  }

  // ─── Online mode: order operations by server ID ───

  static Future<Order?> getOrderByServerId(String serverId) async {
    final result = await ApiService.get('/orders/$serverId');
    if (result['success'] == true) {
      return Order.fromJson(result);
    }
    return null;
  }

  static Future<bool> deleteOrder(Order order) async {
    if (_isOnlineMode && order.serverId != null) {
      final result = await ApiService.delete('/orders/${order.serverId}');
      return result['success'] == true;
    }
    // Offline mode
    if (order.id != null) {
      await DatabaseService.softDeleteOrder(order.id!);
      if (order.serverId != null && order.serverId!.isNotEmpty) {
        await SyncService.addToQueue(
          entityType: 'order',
          entityId: order.id!,
          action: 'delete',
          payload: {'id': order.serverId},
        );
      }
      return true;
    }
    return false;
  }

  static Future<bool> updateOrderStatus(Order order, String newStatus) async {
    if (_isOnlineMode && order.serverId != null) {
      final result = await ApiService.post(
          '/orders/${order.serverId}/status', {'status': newStatus});
      return result['success'] == true;
    }
    // Offline mode
    if (order.id != null) {
      await DatabaseService.updateOrderStatus(order.id!, newStatus);
      if (order.serverId != null && order.serverId!.isNotEmpty) {
        await SyncService.addToQueue(
          entityType: 'order',
          entityId: order.id!,
          action: 'update',
          payload: {'id': order.serverId, 'status': newStatus},
        );
      }
      return true;
    }
    return false;
  }

  static Future<bool> updateOrder(Order order, Map<String, dynamic> updates) async {
    if (_isOnlineMode && order.serverId != null) {
      final result = await ApiService.put('/orders/${order.serverId}', {
        'orderType': order.orderType,
        'stitchingAmount': updates['stitchingAmount'] ?? order.stitchingAmount,
        'materialAmount': updates['materialAmount'] ?? order.materialAmount,
        'discount': updates['discount'] ?? 0,
        'dueDate': updates['dueDate'],
        'designNotes': updates['notes'] ?? order.notes,
        'isUrgent': false,
      });
      return result['success'] == true;
    }
    return false;
  }

  // ─── Spendings (always API) ───

  static Future<List<Map<String, dynamic>>> getSpendings() async {
    final result = await ApiService.get('/spendings');
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
