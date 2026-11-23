import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/local_cache.dart';
import '../models/order.dart';

class OrdersController extends ChangeNotifier {
  OrdersController(this.backend, this.cache);

  final Backend backend;
  final LocalCache cache;

  String? _userId;
  List<Order> _orders = [];
  bool _loading = false;
  bool _offline = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get loading => _loading;
  bool get offline => _offline;
  String? get error => _error;
  int get openCount => _orders.where((o) => o.status.isOpen).length;
  int get pendingCount =>
      _orders.where((o) => o.status == OrderStatus.pending).length;

  /// New orders + receipts waiting to be checked (owner's to-do badge).
  int get needsActionCount => _orders
      .where((o) => o.status == OrderStatus.pending || o.awaitingVerification)
      .length;

  Order? byId(String id) => _orders.where((o) => o.id == id).firstOrNull;

  Future<void> load(String userId) async {
    if (_userId != userId) {
      _userId = userId;
      _orders = cache.loadOrders(userId);
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await backend.fetchOrders();
      _offline = false;
      await cache.saveOrders(userId, _orders);
    } on AppException catch (e) {
      _offline = _orders.isNotEmpty;
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final id = _userId;
    if (id != null) await load(id);
  }

  Future<Order> place(OrderDraft draft) async {
    final order = await backend.placeOrder(draft);
    _orders = [order, ..._orders];
    _persist();
    notifyListeners();
    return order;
  }

  Future<Order> reload(String id) async {
    final order = await backend.fetchOrder(id);
    _replace(order);
    return order;
  }

  Future<Order> setStatus(String id, OrderStatus status) async {
    final order = await backend.updateOrderStatus(id, status);
    _replace(order);
    return order;
  }

  Future<Order> markPaid(String id, {String? reference}) async {
    final order = await backend.markOrderPaid(id, reference: reference);
    _replace(order);
    return order;
  }

  Future<Order> submitReceipt(String id, Uint8List bytes, String fileName) async {
    final order = await backend.submitPaymentReceipt(id, bytes, fileName);
    _replace(order);
    return order;
  }

  Future<Order> reviewReceipt(String id, {required bool approve}) async {
    final order = await backend.reviewPaymentReceipt(id, approve: approve);
    _replace(order);
    return order;
  }

  Future<Order> payWithFpx(String id, String bank) async {
    final order = await backend.payWithFpxSandbox(id, bank);
    _replace(order);
    return order;
  }

  void _replace(Order order) {
    final i = _orders.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      _orders[i] = order;
    } else {
      _orders = [order, ..._orders];
    }
    _persist();
    notifyListeners();
  }

  void _persist() {
    final id = _userId;
    if (id != null) cache.saveOrders(id, _orders);
  }

  void clear() {
    _userId = null;
    _orders = [];
    _error = null;
    notifyListeners();
  }
}
