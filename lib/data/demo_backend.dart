import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../config/shop_config.dart';
import '../core/pricing.dart';
import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'backend.dart';
import 'demo_seed.dart';
import 'local_cache.dart';

/// On-device implementation of [Backend] used when no cloud keys are set.
///
/// It enforces the same business rules as the server (stock checks, prices
/// from the catalogue, delivery radius, role permissions) so the app behaves
/// identically during a demo. Passwords are stored as salted SHA-256 hashes.
class DemoBackend implements Backend {
  DemoBackend(this._cache) {
    _load();
  }

  final LocalCache _cache;
  static const _dbKey = 'demo.db.v1';
  final _rnd = Random();

  late List<Map<String, dynamic>> _users; // AppUser map + salt + hash
  late List<Product> _products;
  late List<Order> _orders;
  late List<Expense> _expenses;
  late int _nextOrderNo;
  String? _sessionUserId;

  @override
  bool get isDemo => true;
  @override
  bool get supportsImageUpload => false;

  // ------------------------------------------------------------ storage
  void _load() {
    final raw = _cache.readRaw(_dbKey);
    if (raw == null) {
      _seed();
      return;
    }
    try {
      final db = jsonDecode(raw) as Map<String, dynamic>;
      _users = (db['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _products = (db['products'] as List)
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _orders = (db['orders'] as List)
          .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _expenses = (db['expenses'] as List)
          .map((e) => Expense.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _nextOrderNo = db['nextOrderNo'] as int;
      _sessionUserId = db['session'] as String?;
    } catch (_) {
      _seed();
    }
  }

  void _seed() {
    final now = DateTime.now();
    _users = [
      _newUserRecord(
        id: 'u_admin',
        email: DemoSeed.adminEmail,
        password: DemoSeed.adminPassword,
        fullName: 'Boss Botak',
        phone: ShopConfig.displayPhone,
        role: UserRole.admin,
      ),
      _newUserRecord(
        id: 'u_aisyah',
        email: DemoSeed.customerEmail,
        password: DemoSeed.customerPassword,
        fullName: 'Aisyah Rahman',
        phone: '012-3456789',
        address: 'No 12, Jalan Bukit Pasir, 83000 Batu Pahat, Johor',
        lat: ShopConfig.shopLat + 0.02,
        lng: ShopConfig.shopLng + 0.03,
      ),
    ];
    _products = DemoSeed.products(now);
    _orders = DemoSeed.orders(_products, now, demoCustomerId: 'u_aisyah');
    _expenses = DemoSeed.expenses(now);
    _nextOrderNo = _orders.isEmpty
        ? 1001
        : _orders.map((o) => o.orderNo).reduce(max) + 1;
    _sessionUserId = null;
    _persist();
  }

  Future<void> _persist() => _cache.writeRaw(
        _dbKey,
        jsonEncode({
          'users': _users,
          'products': _products.map((p) => p.toMap()).toList(),
          'orders': _orders.map((o) => o.toMap()).toList(),
          'expenses': _expenses.map((e) => e.toMap()).toList(),
          'nextOrderNo': _nextOrderNo,
          'session': _sessionUserId,
        }),
      );

  /// Restores the original sample data (used from the Profile screen).
  Future<void> resetDemoData() async {
    _seed();
    await _persist();
  }

  Map<String, dynamic> _newUserRecord({
    required String id,
    required String email,
    required String password,
    required String fullName,
    required String phone,
    UserRole role = UserRole.customer,
    String address = '',
    double? lat,
    double? lng,
  }) {
    final salt = base64Url.encode(List.generate(16, (_) => _rnd.nextInt(256)));
    return {
      ...AppUser(
        id: id,
        email: email.toLowerCase(),
        fullName: fullName,
        phone: phone,
        role: role,
        address: address,
        lat: lat,
        lng: lng,
        createdAt: DateTime.now(),
      ).toMap(),
      'salt': salt,
      'hash': _hash(salt, password),
    };
  }

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(999)}';

  Future<void> _latency() =>
      Future.delayed(Duration(milliseconds: 250 + _rnd.nextInt(250)));

  AppUser get _me {
    final rec = _users.where((u) => u['id'] == _sessionUserId).firstOrNull;
    if (rec == null) throw const AppException('Please sign in again.');
    return AppUser.fromMap(rec);
  }

  void _requireAdmin() {
    if (!_me.isAdmin) throw const AppException('You are not allowed to do that.');
  }

  // --------------------------------------------------------------- auth
  @override
  Future<AppUser?> restoreSession() async {
    if (_sessionUserId == null) return null;
    try {
      return _me;
    } on AppException {
      return null;
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    await _latency();
    final rec = _users
        .where((u) => u['email'] == email.trim().toLowerCase())
        .firstOrNull;
    if (rec == null || rec['hash'] != _hash(rec['salt'] as String, password)) {
      throw const AppException('Wrong email or password.');
    }
    _sessionUserId = rec['id'] as String;
    await _persist();
    return AppUser.fromMap(rec);
  }

  @override
  Future<AppUser> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _latency();
    if (_users.any((u) => u['email'] == email.trim().toLowerCase())) {
      throw const AppException('This email is already registered. Please sign in.');
    }
    final rec = _newUserRecord(
      id: _id('u'),
      email: email.trim(),
      password: password,
      fullName: fullName.trim(),
      phone: phone.trim(),
    );
    _users.add(rec);
    _sessionUserId = rec['id'] as String;
    await _persist();
    return AppUser.fromMap(rec);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _latency();
    throw const AppException(
        'Password reset emails are only available when connected to the cloud backend.');
  }

  @override
  Future<void> signOut() async {
    _sessionUserId = null;
    await _persist();
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    await _latency();
    final i = _users.indexWhere((u) => u['id'] == _me.id);
    _users[i] = {..._users[i], ...user.toProfileUpdate()};
    await _persist();
    return AppUser.fromMap(_users[i]);
  }

  // ------------------------------------------------------------ products
  @override
  Future<List<Product>> fetchProducts({bool includeInactive = false}) async {
    await _latency();
    return _products.where((p) => includeInactive || p.isActive).toList()
      ..sort((a, b) {
        final c = a.category.compareTo(b.category);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
  }

  @override
  Future<Product> saveProduct(Product product) async {
    await _latency();
    _requireAdmin();
    if (product.isNew) {
      final p = product.copyWith(id: _id('p'));
      _products.add(p);
      await _persist();
      return p;
    }
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i < 0) throw const AppException('Product not found.');
    _products[i] = product;
    await _persist();
    return product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _latency();
    _requireAdmin();
    _products.removeWhere((p) => p.id == id);
    await _persist();
  }

  @override
  Future<Product> adjustStock(String productId, int delta) async {
    await _latency();
    _requireAdmin();
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) throw const AppException('Product not found.');
    final newStock = _products[i].stock + delta;
    if (newStock < 0) throw const AppException('Stock cannot go below zero.');
    _products[i] = _products[i].copyWith(stock: newStock);
    await _persist();
    return _products[i];
  }

  @override
  Future<String> uploadProductImage(Uint8List bytes, String fileName) async =>
      throw const AppException('Photo upload needs the cloud backend.');

  // --------------------------------------------------------------- orders
  @override
  Future<Order> placeOrder(OrderDraft d) async {
    await _latency();
    final me = _me;
    if (d.lines.isEmpty) throw const AppException('Your cart is empty.');

    final items = <OrderItem>[];
    final updated = <int, Product>{};
    for (final line in d.lines.entries) {
      if (line.value <= 0) throw const AppException('Invalid quantity.');
      final i = _products.indexWhere((p) => p.id == line.key && p.isActive);
      if (i < 0) throw const AppException('A product in your cart is no longer available.');
      final p = _products[i];
      if (p.stock < line.value) {
        throw AppException('Sorry, only ${p.stock} left for ${p.name}.');
      }
      updated[i] = p.copyWith(stock: p.stock - line.value);
      items.add(OrderItem(
        productId: p.id,
        productName: p.name,
        unitPrice: p.price,
        unitCost: p.cost,
        quantity: line.value,
      ));
    }

    final delivery = d.fulfilment == Fulfilment.delivery;
    double? km;
    if (delivery) {
      if (d.lat == null || d.lng == null || d.address.trim().isEmpty) {
        throw const AppException('Please set a delivery address.');
      }
      km = haversineKm(ShopConfig.shopLat, ShopConfig.shopLng, d.lat!, d.lng!);
      if (!PricingPolicy.isDeliverable(km)) {
        throw const AppException('Sorry, this address is outside our delivery area.');
      }
    }
    final subtotal = items.fold(0.0, (s, i) => s + i.lineTotal);
    final totals =
        PricingPolicy.totals(subtotal: subtotal, delivery: delivery, distanceKm: km ?? 0);

    final ownerSale = me.isAdmin && d.source != OrderSource.app;
    final order = Order(
      id: _id('o'),
      orderNo: _nextOrderNo++,
      customerId: ownerSale ? null : me.id,
      customerName: ownerSale ? (d.customerName ?? 'Walk-in customer') : me.fullName,
      customerPhone: ownerSale ? (d.customerPhone ?? '') : me.phone,
      items: items,
      subtotal: totals.subtotal,
      deliveryFee: totals.deliveryFee,
      discount: totals.discount,
      total: totals.total,
      fulfilment: d.fulfilment,
      address: delivery ? d.address : '',
      lat: delivery ? d.lat : null,
      lng: delivery ? d.lng : null,
      distanceKm: km == null ? null : double.parse(km.toStringAsFixed(1)),
      scheduledFor: d.scheduledFor,
      notes: d.notes,
      paymentMethod: d.paymentMethod,
      paymentStatus:
          ownerSale && d.markPaid ? PaymentStatus.paid : PaymentStatus.unpaid,
      status: ownerSale ? OrderStatus.confirmed : OrderStatus.pending,
      source: ownerSale ? d.source : OrderSource.app,
      createdAt: DateTime.now(),
    );
    updated.forEach((i, p) => _products[i] = p);
    _orders.insert(0, order);
    await _persist();
    return order;
  }

  @override
  Future<List<Order>> fetchOrders() async {
    await _latency();
    final me = _me;
    final list = me.isAdmin
        ? _orders.toList()
        : _orders.where((o) => o.customerId == me.id).toList();
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Order _visibleOrder(String id) {
    final me = _me;
    final o = _orders.where((o) => o.id == id).firstOrNull;
    if (o == null || (!me.isAdmin && o.customerId != me.id)) {
      throw const AppException('Order not found.');
    }
    return o;
  }

  @override
  Future<Order> fetchOrder(String id) async {
    await _latency();
    return _visibleOrder(id);
  }

  @override
  Future<Order> updateOrderStatus(String id, OrderStatus status) async {
    await _latency();
    final me = _me;
    final o = _visibleOrder(id);
    if (!me.isAdmin &&
        !(status == OrderStatus.cancelled && o.status == OrderStatus.pending)) {
      throw const AppException('You can only cancel an order while it is pending.');
    }
    if (!o.status.isOpen) {
      throw AppException('This order is already ${o.status.label.toLowerCase()}.');
    }
    if (status == OrderStatus.cancelled) {
      for (final item in o.items) {
        final i = _products.indexWhere((p) => p.id == item.productId);
        if (i >= 0) {
          _products[i] = _products[i].copyWith(stock: _products[i].stock + item.quantity);
        }
      }
    }
    final updated = o.copyWith(status: status);
    _orders[_orders.indexWhere((x) => x.id == id)] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Order> markOrderPaid(String id, {String? reference}) async {
    await _latency();
    _requireAdmin();
    final o = _visibleOrder(id);
    final updated =
        o.copyWith(paymentStatus: PaymentStatus.paid, paymentRef: reference);
    _orders[_orders.indexWhere((x) => x.id == id)] = updated;
    await _persist();
    return updated;
  }

  // -------------------------------------------------------------- finance
  @override
  Future<List<Expense>> fetchExpenses() async {
    await _latency();
    _requireAdmin();
    return _expenses.toList()..sort((a, b) => b.spentOn.compareTo(a.spentOn));
  }

  @override
  Future<Expense> addExpense(Expense e) async {
    await _latency();
    _requireAdmin();
    final saved = Expense(
      id: _id('e'),
      title: e.title,
      category: e.category,
      amount: e.amount,
      spentOn: e.spentOn,
      note: e.note,
    );
    _expenses.add(saved);
    await _persist();
    return saved;
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _latency();
    _requireAdmin();
    _expenses.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<List<AppUser>> fetchCustomerProfiles() async {
    await _latency();
    _requireAdmin();
    return _users.map(AppUser.fromMap).where((u) => !u.isAdmin).toList();
  }

  // ------------------------------------------------------------- payments
  Order _ownOrderForPayment(String id) {
    final me = _me;
    final o = _visibleOrder(id);
    if (o.customerId != me.id) throw const AppException('You can only pay for your own order.');
    if (o.status == OrderStatus.cancelled) throw const AppException('This order was cancelled.');
    if (o.isPaid) throw const AppException('This order is already paid.');
    return o;
  }

  Future<Order> _save(Order updated) async {
    _orders[_orders.indexWhere((x) => x.id == updated.id)] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Order> submitPaymentReceipt(String orderId, Uint8List imageBytes, String fileName) async {
    await _latency();
    final o = _ownOrderForPayment(orderId);
    if (imageBytes.length > 1500 * 1024) {
      throw const AppException('The receipt image is too large (max 1.5 MB).');
    }
    // Demo mode keeps the image inside the on-device database as a data URI.
    final dataUri = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    return _save(o.copyWith(
      paymentStatus: PaymentStatus.pendingVerification,
      paymentMethod: PaymentMethod.duitnow,
      receiptUrl: dataUri,
    ));
  }

  @override
  Future<Order> reviewPaymentReceipt(String orderId, {required bool approve}) async {
    await _latency();
    _requireAdmin();
    final o = _visibleOrder(orderId);
    if (!o.awaitingVerification) throw const AppException('There is no receipt waiting to be checked.');
    return _save(approve
        ? o.copyWith(paymentStatus: PaymentStatus.paid, paymentRef: 'DuitNow receipt verified')
        : o.copyWith(paymentStatus: PaymentStatus.unpaid, clearReceipt: true));
  }

  @override
  Future<String> receiptImageUrl(Order order) async => order.receiptUrl ?? '';

  @override
  Future<Order> payWithFpxSandbox(String orderId, String bankName) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // "talking to the bank"
    final o = _ownOrderForPayment(orderId);
    final ref = 'FPX${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
    return _save(o.copyWith(
      paymentStatus: PaymentStatus.paid,
      paymentMethod: PaymentMethod.fpx,
      paymentRef: '$ref · $bankName',
      clearReceipt: true,
    ));
  }
}
