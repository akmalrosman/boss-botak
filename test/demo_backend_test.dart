import 'package:boss_botak/config/shop_config.dart';
import 'package:boss_botak/data/backend.dart';
import 'package:boss_botak/data/demo_backend.dart';
import 'package:boss_botak/data/demo_seed.dart';
import 'package:boss_botak/data/local_cache.dart';
import 'dart:typed_data';

import 'package:boss_botak/models/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Functional tests of the business rules (same rules as the SQL functions).
void main() {
  late DemoBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = DemoBackend(LocalCache(await SharedPreferences.getInstance()));
  });

  test('rejects a wrong password and accepts the right one', () async {
    await expectLater(
      () => backend.signIn(email: DemoSeed.customerEmail, password: 'wrong'),
      throwsA(isA<AppException>()),
    );
    final user = await backend.signIn(
        email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
    expect(user.isAdmin, isFalse);
  });

  test('placing an order uses catalogue prices and reduces stock', () async {
    await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
    final before = (await backend.fetchProducts()).firstWhere((p) => p.id == 'p_pepes_ikan');

    final order = await backend.placeOrder(const OrderDraft(
      lines: {'p_pepes_ikan': 3},
      fulfilment: Fulfilment.pickup,
      paymentMethod: PaymentMethod.duitnow,
    ));

    expect(order.subtotal, before.price * 3);
    expect(order.status, OrderStatus.pending);
    expect(order.customerName, 'Aisyah Rahman');
    final after = (await backend.fetchProducts()).firstWhere((p) => p.id == 'p_pepes_ikan');
    expect(after.stock, before.stock - 3);
  });

  test('cannot order more than available stock', () async {
    await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
    await expectLater(
      () => backend.placeOrder(const OrderDraft(
        lines: {'p_pepes_ayam': 999},
        fulfilment: Fulfilment.pickup,
        paymentMethod: PaymentMethod.duitnow,
      )),
      throwsA(isA<AppException>()),
    );
  });

  test('delivery outside the radius is rejected, inside gets a fee', () async {
    await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
    await expectLater(
      () => backend.placeOrder(const OrderDraft(
        lines: {'p_otak_ori': 1},
        fulfilment: Fulfilment.delivery,
        paymentMethod: PaymentMethod.duitnow,
        address: 'Johor Bahru',
        lat: 1.4927,
        lng: 103.7414,
      )),
      throwsA(isA<AppException>()),
    );
    final ok = await backend.placeOrder(const OrderDraft(
      lines: {'p_otak_ori': 1},
      fulfilment: Fulfilment.delivery,
      paymentMethod: PaymentMethod.duitnow,
      address: 'Near the kitchen',
      lat: ShopConfig.shopLat + 0.01,
      lng: ShopConfig.shopLng,
    ));
    expect(ok.deliveryFee, 5);
    expect(ok.total, 17);
  });

  test('customers cannot see admin data or change order progress', () async {
    await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
    await expectLater(() => backend.fetchExpenses(), throwsA(isA<AppException>()));
    final order = await backend.placeOrder(const OrderDraft(
      lines: {'p_otak_ori': 1},
      fulfilment: Fulfilment.pickup,
      paymentMethod: PaymentMethod.duitnow,
    ));
    await expectLater(() => backend.updateOrderStatus(order.id, OrderStatus.completed),
        throwsA(isA<AppException>()));
    // ...but may cancel their own pending order.
    final cancelled = await backend.updateOrderStatus(order.id, OrderStatus.cancelled);
    expect(cancelled.status, OrderStatus.cancelled);
  });

  test('cancelling returns items to stock; owner sales are recorded as confirmed', () async {
    await backend.signIn(email: DemoSeed.adminEmail, password: DemoSeed.adminPassword);
    final stock0 = (await backend.fetchProducts()).firstWhere((p) => p.id == 'p_combo').stock;

    final sale = await backend.placeOrder(const OrderDraft(
      lines: {'p_combo': 2},
      fulfilment: Fulfilment.pickup,
      paymentMethod: PaymentMethod.duitnow,
      customerName: 'Walk-in Pakcik',
      customerPhone: '012-1112222',
      source: OrderSource.walkIn,
      markPaid: true,
    ));
    expect(sale.status, OrderStatus.confirmed);
    expect(sale.isPaid, isTrue);
    expect(sale.customerName, 'Walk-in Pakcik');

    await backend.updateOrderStatus(sale.id, OrderStatus.cancelled);
    final stock1 = (await backend.fetchProducts()).firstWhere((p) => p.id == 'p_combo').stock;
    expect(stock1, stock0);
  });

  group('Payments', () {
    Future<Order> newOrder() => backend.placeOrder(const OrderDraft(
          lines: {'p_otak_ori': 2},
          fulfilment: Fulfilment.pickup,
          paymentMethod: PaymentMethod.duitnow,
        ));

    test('DuitNow: receipt upload -> verifying -> owner approves -> paid', () async {
      await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
      final order = await newOrder();
      expect(order.paymentStatus, PaymentStatus.unpaid);

      final sent = await backend.submitPaymentReceipt(
          order.id, Uint8List.fromList(List.filled(2000, 7)), 'receipt.jpg');
      expect(sent.paymentStatus, PaymentStatus.pendingVerification);
      expect(sent.hasReceipt, isTrue);

      // Customer cannot approve their own receipt.
      await expectLater(() => backend.reviewPaymentReceipt(order.id, approve: true),
          throwsA(isA<AppException>()));

      await backend.signOut();
      await backend.signIn(email: DemoSeed.adminEmail, password: DemoSeed.adminPassword);
      final approved = await backend.reviewPaymentReceipt(order.id, approve: true);
      expect(approved.isPaid, isTrue);
    });

    test('DuitNow: rejected receipt goes back to unpaid', () async {
      await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
      final order = await newOrder();
      await backend.submitPaymentReceipt(order.id, Uint8List(100), 'r.jpg');
      await backend.signOut();
      await backend.signIn(email: DemoSeed.adminEmail, password: DemoSeed.adminPassword);
      final rejected = await backend.reviewPaymentReceipt(order.id, approve: false);
      expect(rejected.paymentStatus, PaymentStatus.unpaid);
      expect(rejected.hasReceipt, isFalse);
    });

    test('FPX sandbox marks the order paid with a reference', () async {
      await backend.signIn(email: DemoSeed.customerEmail, password: DemoSeed.customerPassword);
      final order = await newOrder();
      final paid = await backend.payWithFpxSandbox(order.id, 'Maybank2u');
      expect(paid.isPaid, isTrue);
      expect(paid.paymentMethod, PaymentMethod.fpx);
      expect(paid.paymentRef, contains('Maybank2u'));
      // Cannot pay twice.
      await expectLater(() => backend.payWithFpxSandbox(order.id, 'CIMB Clicks'), throwsA(isA<AppException>()));
    });
  });
}
