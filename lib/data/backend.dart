import 'dart:typed_data';

import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Friendly error shown to the user.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contract for the app's backend.
///
/// * [SupabaseBackend] - cloud database (Supabase Postgres + Auth + Storage).
/// * [DemoBackend]     - on-device data for demos / offline showcase.
abstract class Backend {
  bool get isDemo;
  bool get supportsImageUpload;

  // ---------- Authentication ----------
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Future<AppUser> updateProfile(AppUser user);

  // ---------- Products & inventory ----------
  Future<List<Product>> fetchProducts({bool includeInactive = false});
  Future<Product> saveProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<Product> adjustStock(String productId, int delta);
  Future<String> uploadProductImage(Uint8List bytes, String fileName);

  // ---------- Orders ----------
  Future<Order> placeOrder(OrderDraft draft);

  /// Customers get their own orders; the owner gets every order.
  Future<List<Order>> fetchOrders();
  Future<Order> fetchOrder(String id);
  Future<Order> updateOrderStatus(String id, OrderStatus status);
  Future<Order> markOrderPaid(String id, {String? reference});

  // ---------- Finance & customers (owner only) ----------
  Future<List<Expense>> fetchExpenses();
  Future<Expense> addExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Future<List<AppUser>> fetchCustomerProfiles();

  // ---------- Payments: DuitNow QR + FPX ----------
  /// Customer uploads a DuitNow transfer receipt -> status "pending verification".
  Future<Order> submitPaymentReceipt(String orderId, Uint8List imageBytes, String fileName);

  /// Owner approves (-> paid) or rejects (-> unpaid, receipt removed) a receipt.
  Future<Order> reviewPaymentReceipt(String orderId, {required bool approve});

  /// A URL the app can display for the order's receipt image.
  Future<String> receiptImageUrl(Order order);

  /// FPX sandbox: simulates a successful online-banking payment.
  /// (No real bank is contacted - to be replaced by a real FPX gateway.)
  Future<Order> payWithFpxSandbox(String orderId, String bankName);
}
