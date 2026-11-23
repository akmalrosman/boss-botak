import 'package:flutter/foundation.dart';

import '../core/analytics.dart';
import '../data/backend.dart';
import '../data/local_cache.dart';
import '../models/product.dart';

/// Product catalogue + inventory. Falls back to the cached catalogue when the
/// network is unavailable so customers can still browse.
class CatalogController extends ChangeNotifier {
  CatalogController(this.backend, this.cache);

  final Backend backend;
  final LocalCache cache;

  List<Product> _products = [];
  bool _loading = false;
  bool _offline = false;
  String? _error;
  bool _includeInactive = false;

  List<Product> get products => _products;
  List<Product> get activeProducts => _products.where((p) => p.isActive).toList();
  bool get loading => _loading;
  bool get offline => _offline;
  String? get error => _error;
  List<Product> get lowStock => Analytics.lowStock(_products);

  Product? byId(String id) => _products.where((p) => p.id == id).firstOrNull;

  Future<void> load({bool includeInactive = false}) async {
    _includeInactive = includeInactive;
    _loading = true;
    _error = null;
    if (_products.isEmpty) _products = cache.loadProducts();
    notifyListeners();
    try {
      _products = await backend.fetchProducts(includeInactive: includeInactive);
      _offline = false;
      await cache.saveProducts(_products.where((p) => p.isActive).toList());
    } on AppException catch (e) {
      _offline = _products.isNotEmpty;
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(includeInactive: _includeInactive);

  Future<Product> save(Product product) async {
    final saved = await backend.saveProduct(product);
    final i = _products.indexWhere((p) => p.id == saved.id);
    if (i >= 0) {
      _products[i] = saved;
    } else {
      _products = [..._products, saved];
    }
    notifyListeners();
    return saved;
  }

  Future<void> delete(String id) async {
    await backend.deleteProduct(id);
    _products = _products.where((p) => p.id != id).toList();
    notifyListeners();
  }

  Future<void> adjustStock(String id, int delta) async {
    final updated = await backend.adjustStock(id, delta);
    _replace(updated);
  }

  Future<String> uploadImage(Uint8List bytes, String name) =>
      backend.uploadProductImage(bytes, name);

  void _replace(Product p) {
    final i = _products.indexWhere((x) => x.id == p.id);
    if (i >= 0) _products[i] = p;
    notifyListeners();
  }

  void clear() {
    _products = [];
    _error = null;
    notifyListeners();
  }
}
