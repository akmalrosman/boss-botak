import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'backend.dart';

/// Cloud backend on Supabase (managed PostgreSQL).
///
/// Security notes:
/// * all requests go over HTTPS (TLS) to `SUPABASE_URL`
/// * the anon key is injected at build time, never hardcoded
/// * Row Level Security policies in `supabase/schema.sql` decide what each
///   user may read/write; customers can only see their own orders and only
///   the owner (role = admin) can change products, expenses or order status
/// * orders are created through the `place_order` SQL function which re-reads
///   prices from the database and checks stock atomically.
class SupabaseBackend implements Backend {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  static const _imageBucket = 'product-images';
  static const _receiptBucket = 'payment-receipts';

  @override
  bool get isDemo => false;
  @override
  bool get supportsImageUpload => true;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run().timeout(const Duration(seconds: 20));
    } on AuthException catch (e) {
      throw AppException(_authMessage(e));
    } on PostgrestException catch (e) {
      throw AppException(_dbMessage(e));
    } on StorageException catch (e) {
      throw AppException('Upload failed: ${e.message}');
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map ? details['error'] : null;
      throw AppException(msg?.toString() ?? 'Payment service error (${e.status}).');
    } on TimeoutException {
      throw const AppException('The server took too long to respond. Please try again.');
    } on AppException {
      rethrow;
    } catch (e) {
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('Failed host lookup') ||
          text.contains('ClientException') ||
          text.contains('XMLHttpRequest')) {
        throw const AppException('No internet connection.');
      }
      throw AppException('Something went wrong: $text');
    }
  }

  String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Wrong email or password.';
    if (m.contains('already registered')) {
      return 'This email is already registered. Please sign in.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first (check your inbox).';
    }
    return e.message;
  }

  String _dbMessage(PostgrestException e) {
    // Messages raised by our own SQL functions are already user friendly.
    if (e.code == 'P0001') return e.message;
    if (e.code == '42501') return 'You are not allowed to do that.';
    return e.message;
  }

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Please sign in again.');
    return id;
  }

  Future<AppUser> _fetchProfile(String id) async {
    final row = await _client.from('profiles').select().eq('id', id).single();
    return AppUser.fromMap(row);
  }

  // ---------------------------------------------------------------- auth
  @override
  Future<AppUser?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      return await _guard(() => _fetchProfile(user.id));
    } on AppException {
      return null;
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final res = await _client.auth
            .signInWithPassword(email: email.trim(), password: password);
        return _fetchProfile(res.user!.id);
      });

  @override
  Future<AppUser> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim(), 'phone': phone.trim()},
        );
        if (res.session == null) {
          throw const AppException(
              'Account created! Please confirm your email, then sign in.');
        }
        return _fetchProfile(res.user!.id);
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<AppUser> updateProfile(AppUser user) => _guard(() async {
        final row = await _client
            .from('profiles')
            .update(user.toProfileUpdate())
            .eq('id', user.id)
            .select()
            .single();
        return AppUser.fromMap(row);
      });

  // ------------------------------------------------------------ products
  @override
  Future<List<Product>> fetchProducts({bool includeInactive = false}) =>
      _guard(() async {
        var query = _client.from('products').select();
        if (!includeInactive) query = query.eq('is_active', true);
        final rows = await query.order('category').order('name');
        return rows.map(Product.fromMap).toList();
      });

  @override
  Future<Product> saveProduct(Product product) => _guard(() async {
        final data = product.toWriteMap();
        final row = product.isNew
            ? await _client.from('products').insert(data).select().single()
            : await _client
                .from('products')
                .update(data)
                .eq('id', product.id)
                .select()
                .single();
        return Product.fromMap(row);
      });

  @override
  Future<void> deleteProduct(String id) =>
      _guard(() => _client.from('products').delete().eq('id', id));

  @override
  Future<Product> adjustStock(String productId, int delta) => _guard(() async {
        final row = await _client.rpc('adjust_stock',
            params: {'p_product_id': productId, 'p_delta': delta});
        return Product.fromMap(Map<String, dynamic>.from(row as Map));
      });

  @override
  Future<String> uploadProductImage(Uint8List bytes, String fileName) =>
      _guard(() async {
        final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path = 'products/${DateTime.now().millisecondsSinceEpoch}_$safeName';
        await _client.storage.from(_imageBucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        return _client.storage.from(_imageBucket).getPublicUrl(path);
      });

  // -------------------------------------------------------------- orders
  static const _orderSelect = '*, order_items(*)';

  @override
  Future<Order> placeOrder(OrderDraft d) => _guard(() async {
        final id = await _client.rpc('place_order', params: {
          'p_items': [
            for (final e in d.lines.entries)
              {'product_id': e.key, 'quantity': e.value},
          ],
          'p_fulfilment': d.fulfilment.name,
          'p_address': d.address,
          'p_lat': d.lat,
          'p_lng': d.lng,
          'p_scheduled_for': d.scheduledFor?.toIso8601String().substring(0, 10),
          'p_notes': d.notes,
          'p_payment_method': d.paymentMethod.name,
          'p_customer_name': d.customerName,
          'p_customer_phone': d.customerPhone,
          'p_source': d.source.dbValue,
          'p_mark_paid': d.markPaid,
        });
        return _fetchOrder(id as String);
      });

  Future<Order> _fetchOrder(String id) async {
    final row =
        await _client.from('orders').select(_orderSelect).eq('id', id).single();
    return Order.fromMap(row);
  }

  @override
  Future<List<Order>> fetchOrders() => _guard(() async {
        _uid; // ensures signed in; RLS filters rows per user/role.
        final rows = await _client
            .from('orders')
            .select(_orderSelect)
            .order('created_at', ascending: false)
            .limit(1000);
        return rows.map(Order.fromMap).toList();
      });

  @override
  Future<Order> fetchOrder(String id) => _guard(() => _fetchOrder(id));

  @override
  Future<Order> updateOrderStatus(String id, OrderStatus status) =>
      _guard(() async {
        await _client.rpc('set_order_status',
            params: {'p_order_id': id, 'p_status': status.name});
        return _fetchOrder(id);
      });

  @override
  Future<Order> markOrderPaid(String id, {String? reference}) =>
      _guard(() async {
        await _client.from('orders').update({
          'payment_status': 'paid',
          'payment_ref': ?reference,
        }).eq('id', id);
        return _fetchOrder(id);
      });

  // ------------------------------------------------------------- finance
  @override
  Future<List<Expense>> fetchExpenses() => _guard(() async {
        final rows = await _client
            .from('expenses')
            .select()
            .order('spent_on', ascending: false);
        return rows.map(Expense.fromMap).toList();
      });

  @override
  Future<Expense> addExpense(Expense e) => _guard(() async {
        final row = await _client
            .from('expenses')
            .insert({...e.toWriteMap(), 'created_by': _uid})
            .select()
            .single();
        return Expense.fromMap(row);
      });

  @override
  Future<void> deleteExpense(String id) =>
      _guard(() => _client.from('expenses').delete().eq('id', id));

  @override
  Future<List<AppUser>> fetchCustomerProfiles() => _guard(() async {
        final rows = await _client.from('profiles').select().eq('role', 'customer');
        return rows.map(AppUser.fromMap).toList();
      });

  // ------------------------------------------------------------ payments
  @override
  Future<Order> submitPaymentReceipt(String orderId, Uint8List imageBytes, String fileName) =>
      _guard(() async {
        // Private bucket; each customer may only write inside their own folder.
        final path = '$_uid/$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from(_receiptBucket).uploadBinary(
              path,
              imageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        await _client.rpc('submit_payment_receipt',
            params: {'p_order_id': orderId, 'p_receipt_path': path});
        return _fetchOrder(orderId);
      });

  @override
  Future<Order> reviewPaymentReceipt(String orderId, {required bool approve}) =>
      _guard(() async {
        await _client.rpc('review_payment_receipt',
            params: {'p_order_id': orderId, 'p_approve': approve});
        return _fetchOrder(orderId);
      });

  @override
  Future<String> receiptImageUrl(Order order) => _guard(() async {
        if (!order.hasReceipt) return '';
        // Short-lived signed link - receipts are never public.
        return _client.storage.from(_receiptBucket).createSignedUrl(order.receiptUrl!, 600);
      });

  @override
  Future<Order> payWithFpxSandbox(String orderId, String bankName) => _guard(() async {
        await Future.delayed(const Duration(milliseconds: 1200));
        await _client.rpc('simulate_fpx_payment',
            params: {'p_order_id': orderId, 'p_bank': bankName});
        return _fetchOrder(orderId);
      });
}
