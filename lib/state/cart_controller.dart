import 'package:flutter/foundation.dart';

import '../data/local_cache.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

/// Shopping cart. Stored locally per user so it survives app restarts and
/// works without internet.
class CartController extends ChangeNotifier {
  CartController(this.cache);

  final LocalCache cache;
  String? _userId;
  List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.lineTotal);

  int quantityOf(String productId) =>
      _items.where((i) => i.product.id == productId).firstOrNull?.quantity ?? 0;

  /// Loads the cart of the signed-in user. Called from AuthGate.build, so it
  /// does not notify: the shells are re-created per user and read it fresh.
  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _items = userId == null ? [] : cache.loadCart(userId);
  }

  /// Adds [qty] of [product]; returns the quantity actually added (stock cap).
  int add(Product product, [int qty = 1]) {
    final current = quantityOf(product.id);
    final allowed = (product.stock - current).clamp(0, qty);
    if (allowed == 0) return 0;
    _set(product, current + allowed);
    return allowed;
  }

  void setQuantity(Product product, int qty) {
    if (qty <= 0) {
      remove(product.id);
      return;
    }
    _set(product, qty.clamp(1, product.stock));
  }

  void remove(String productId) {
    _items = _items.where((i) => i.product.id != productId).toList();
    _changed();
  }

  void restore(CartItem item, int index) {
    _items = [..._items]..insert(index.clamp(0, _items.length), item);
    _changed();
  }

  void clear() {
    _items = [];
    _changed();
  }

  /// Keeps cart prices/stock in sync with the latest catalogue.
  void syncWith(List<Product> products) {
    var changed = false;
    final next = <CartItem>[];
    for (final item in _items) {
      final p = products.where((x) => x.id == item.product.id).firstOrNull;
      if (p == null || !p.isActive) {
        changed = true;
        continue;
      }
      final qty = item.quantity.clamp(0, p.stock);
      if (qty == 0) {
        changed = true;
        continue;
      }
      if (qty != item.quantity || p.price != item.product.price || p.stock != item.product.stock) {
        changed = true;
      }
      next.add(CartItem(product: p, quantity: qty));
    }
    if (changed) {
      _items = next;
      _changed();
    }
  }

  void _set(Product product, int qty) {
    final i = _items.indexWhere((x) => x.product.id == product.id);
    if (i >= 0) {
      _items[i] = CartItem(product: product, quantity: qty);
    } else {
      _items = [..._items, CartItem(product: product, quantity: qty)];
    }
    _changed();
  }

  void _changed() {
    notifyListeners();
    final id = _userId;
    if (id != null) cache.saveCart(id, _items);
  }
}
