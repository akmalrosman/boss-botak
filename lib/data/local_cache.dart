import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Local cache for fast start-up and offline use.
///
/// * cart and settings are user-specific and live only on the device
/// * the product catalogue and the user's orders are cached so the app keeps
///   working (read-only) when the network is down.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  static const _kTheme = 'settings.themeMode';
  static const _kProducts = 'cache.products';
  static String _kCart(String userId) => 'cart.$userId';
  static String _kOrders(String userId) => 'cache.orders.$userId';
  static const _kOrdersSavedAt = 'cache.orders.savedAt';

  // ----- settings -----
  ThemeMode get themeMode => ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_kTheme),
        orElse: () => ThemeMode.system,
      );
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kTheme, mode.name);

  // ----- cart -----
  List<CartItem> loadCart(String userId) {
    final raw = _prefs.getString(_kCart(userId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => CartItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCart(String userId, List<CartItem> items) => _prefs
      .setString(_kCart(userId), jsonEncode(items.map((e) => e.toMap()).toList()));

  // ----- products -----
  List<Product> loadProducts() {
    final raw = _prefs.getString(_kProducts);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProducts(List<Product> products) => _prefs.setString(
      _kProducts, jsonEncode(products.map((p) => p.toMap()).toList()));

  // ----- orders -----
  List<Order> loadOrders(String userId) {
    final raw = _prefs.getString(_kOrders(userId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrders(String userId, List<Order> orders) async {
    await _prefs.setString(
        _kOrders(userId), jsonEncode(orders.map((o) => o.toMap()).toList()));
    await _prefs.setString(_kOrdersSavedAt, DateTime.now().toIso8601String());
  }

  /// Raw key/value access for the demo backend's on-device database.
  String? readRaw(String key) => _prefs.getString(key);
  Future<void> writeRaw(String key, String value) => _prefs.setString(key, value);
}
