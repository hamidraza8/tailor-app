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
      final result = await ApiService.get('/orders?status=Pending&status=Cutting&status=Stitching&status=Finishing&status=Ready');
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
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
    if (_isOnlineMode) {
      // In online mode, id is actually the server ID stored locally
      return DatabaseService.getOrderById(id);
    }
    return DatabaseService.getOrderById(id);
  }

  static Future<int> insertOrder(Order order) async {
    if (_isOnlineMode) {
      final result = await ApiService.post('/orders', order.toJson());
      if (result['success'] == true) {
        // Also save locally for quick access
        final localId = await DatabaseService.insertOrder(order.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to create order');
    }
    final id = await DatabaseService.insertOrder(order);
    await SyncService.addToQueue(entityType: 'order', entityId: id, action: 'create', payload: order.toJson());
    return id;
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
      final result = await ApiService.post('/customers', customer.toJson());
      if (result['success'] == true) {
        final localId = await DatabaseService.insertCustomer(customer.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to create customer');
    }
    final id = await DatabaseService.insertCustomer(customer);
    await SyncService.addToQueue(entityType: 'customer', entityId: id, action: 'create', payload: customer.toJson());
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
      final result = await ApiService.post('/payments', payment.toJson());
      if (result['success'] == true) {
        final localId = await DatabaseService.insertPayment(payment.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to record payment');
    }
    final id = await DatabaseService.insertPayment(payment);
    await SyncService.addToQueue(entityType: 'payment', entityId: id, action: 'create', payload: payment.toJson());
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
      final result = await ApiService.post('/inventory', txn.toJson());
      if (result['success'] == true) {
        final localId = await DatabaseService.insertInventoryTransaction(txn.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to add inventory');
    }
    final id = await DatabaseService.insertInventoryTransaction(txn);
    await SyncService.addToQueue(entityType: 'inventory', entityId: id, action: 'create', payload: txn.toJson());
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
      final result = await ApiService.post('/assets', asset.toJson());
      if (result['success'] == true) {
        final localId = await DatabaseService.insertAsset(asset.copyWith(synced: true));
        return localId;
      }
      throw Exception(result['message'] ?? 'Failed to add asset');
    }
    final id = await DatabaseService.insertAsset(asset);
    await SyncService.addToQueue(entityType: 'asset', entityId: id, action: 'create', payload: asset.toJson());
    return id;
  }

  // ─── Measurements ───

  static Future<int> insertMeasurement(Measurement measurement) async {
    if (_isOnlineMode) {
      // Measurements are part of orders in online mode, just save locally
      return DatabaseService.insertMeasurement(measurement);
    }
    final id = await DatabaseService.insertMeasurement(measurement);
    await SyncService.addToQueue(entityType: 'measurement', entityId: id, action: 'create', payload: measurement.toMap());
    return id;
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
