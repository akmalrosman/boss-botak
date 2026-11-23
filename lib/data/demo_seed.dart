import 'dart:math';

import '../config/shop_config.dart';
import '../core/pricing.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Sample data for Demo mode. Prices are placeholders - edit them in the app
/// (Inventory screen) or here to match Boss Botak's real price list.
class DemoSeed {
  DemoSeed._();

  static const adminEmail = 'boss@bossbotak.demo';
  static const adminPassword = 'BossBotak123';
  static const customerEmail = 'aisyah@demo.my';
  static const customerPassword = 'Demo1234';

  static List<Product> products(DateTime now) => [
        Product(
          id: 'p_otak_ori',
          name: 'Otak-Otak Ikan Original',
          category: 'Otak-Otak',
          unit: '10 pcs / pack',
          price: 12,
          cost: 6.5,
          stock: 80,
          lowStockThreshold: 15,
          imageUrl: 'asset:otak_otak',
          description:
              'Lembut! Berperisa! Spicy fish paste wrapped in leaf strips, Johor style. '
              'Frozen - grill, pan-fry or air-fry for 8-10 minutes.',
          createdAt: now,
        ),
        Product(
          id: 'p_otak_pedas',
          name: 'Otak-Otak Pedas Berapi',
          category: 'Otak-Otak',
          unit: '10 pcs / pack',
          price: 13,
          cost: 7,
          stock: 45,
          lowStockThreshold: 15,
          imageUrl: 'asset:otak_otak',
          description:
              'Our original recipe with extra chilli for those who like it hot. '
              'Keep frozen at -18°C.',
          createdAt: now,
        ),
        Product(
          id: 'p_otak_party',
          name: 'Otak-Otak Party Pack',
          category: 'Otak-Otak',
          unit: '50 pcs / pack',
          price: 55,
          cost: 31,
          stock: 12,
          lowStockThreshold: 5,
          imageUrl: 'asset:otak_otak',
          description: 'Big pack for open house, majlis and parties.',
          createdAt: now,
        ),
        Product(
          id: 'p_pepes_ikan',
          name: 'Pepes Ikan Tenggiri',
          category: 'Pepes',
          unit: '5 pcs / pack',
          price: 15,
          cost: 8.5,
          stock: 40,
          lowStockThreshold: 10,
          imageUrl: 'asset:pepes',
          description:
              'Wangi! Lemak! Padu! Mackerel pepes wrapped in banana leaf with '
              'fragrant spices. Grill or steam 10-12 minutes from frozen.',
          createdAt: now,
        ),
        Product(
          id: 'p_pepes_ayam',
          name: 'Pepes Ayam',
          category: 'Pepes',
          unit: '5 pcs / pack',
          price: 14,
          cost: 7.8,
          stock: 8,
          lowStockThreshold: 10,
          imageUrl: 'asset:pepes',
          description: 'Spiced chicken grilled in banana leaf parcels - a family favourite.',
          createdAt: now,
        ),
        Product(
          id: 'p_combo',
          name: 'Combo Open House',
          category: 'Combo',
          unit: '20 otak-otak + 10 pepes',
          price: 50,
          cost: 28,
          stock: 15,
          lowStockThreshold: 5,
          imageUrl: 'asset:combo',
          description:
              'Khas untuk open house! The best of both - sesuai untuk tetamu & '
              'keluarga tersayang.',
          createdAt: now,
        ),
      ];

  static const _customers = [
    ('Aisyah Rahman', '012-3456789'),
    ('Kak Ros', '013-2233445'),
    ('Encik Hafiz', '019-7788990'),
    ('Mei Ling', '016-5566778'),
    ('Puan Salmah', '011-23456789'),
    ('Rizal Catering', '017-8899001'),
    ('Nurul Huda', '014-6677889'),
  ];

  static List<Order> orders(
    List<Product> products,
    DateTime now, {
    required String demoCustomerId,
  }) {
    final rnd = Random(42);
    final list = <Order>[];
    var no = 1001;
    for (var daysAgo = 75; daysAgo >= 0; daysAgo--) {
      // Busier towards festive season / weekends.
      final day = now.subtract(Duration(days: daysAgo));
      final weekend = day.weekday >= DateTime.friday;
      final count = rnd.nextInt(weekend ? 3 : 2);
      for (var k = 0; k < count; k++) {
        final c = _customers[rnd.nextInt(_customers.length)];
        final lines = <OrderItem>[];
        final picks = (products.toList()..shuffle(rnd)).take(1 + rnd.nextInt(3));
        for (final p in picks) {
          lines.add(OrderItem(
            productId: p.id,
            productName: p.name,
            unitPrice: p.price,
            unitCost: p.cost,
            quantity: 1 + rnd.nextInt(p.price > 40 ? 2 : 5),
          ));
        }
        final subtotal = lines.fold(0.0, (s, i) => s + i.lineTotal);
        final delivery = rnd.nextBool();
        final km = 2 + rnd.nextDouble() * 12;
        final totals = PricingPolicy.totals(
            subtotal: subtotal, delivery: delivery, distanceKm: km);
        final created = DateTime(day.year, day.month, day.day,
            9 + rnd.nextInt(12), rnd.nextInt(60));
        if (created.isAfter(now)) continue;
        final isAisyah = c.$1 == 'Aisyah Rahman';
        final status = daysAgo > 3
            ? (rnd.nextInt(14) == 0 ? OrderStatus.cancelled : OrderStatus.completed)
            : OrderStatus.flow[rnd.nextInt(4)];
        final source = isAisyah
            ? OrderSource.app
            : (rnd.nextInt(3) == 0 ? OrderSource.walkIn : OrderSource.whatsapp);
        list.add(Order(
          id: 'o_$no',
          orderNo: no++,
          customerId: isAisyah ? demoCustomerId : null,
          customerName: c.$1,
          customerPhone: c.$2,
          items: lines,
          subtotal: totals.subtotal,
          deliveryFee: totals.deliveryFee,
          discount: totals.discount,
          total: totals.total,
          fulfilment: delivery ? Fulfilment.delivery : Fulfilment.pickup,
          address: delivery ? 'Taman Bukit Pasir, ${ShopConfig.shopAddress}' : '',
          lat: delivery ? ShopConfig.shopLat + 0.02 : null,
          lng: delivery ? ShopConfig.shopLng + 0.03 : null,
          distanceKm: delivery ? double.parse(km.toStringAsFixed(1)) : null,
          scheduledFor: created.add(Duration(days: 1 + rnd.nextInt(3))),
          paymentMethod:
              rnd.nextBool() ? PaymentMethod.duitnow : PaymentMethod.fpx,
          paymentStatus: status == OrderStatus.completed || rnd.nextBool()
              ? PaymentStatus.paid
              : PaymentStatus.unpaid,
          status: status,
          source: source,
          createdAt: created,
        ));
      }
    }
    return list.reversed.toList();
  }

  static List<Expense> expenses(DateTime now) {
    final items = <(int, String, String, double)>[
      (2, 'Fish paste (ikan tenggiri) 10kg', 'Ingredients', 220),
      (4, 'Banana leaves & lidi', 'Packaging', 35),
      (6, 'Petrol - deliveries', 'Transport', 60),
      (9, 'Vacuum seal bags', 'Packaging', 48),
      (12, 'Facebook ads - Raya promo', 'Marketing', 50),
      (15, 'Spices & coconut milk', 'Ingredients', 95),
      (20, 'Electricity (freezer)', 'Utilities', 120),
      (26, 'Fish paste (ikan tenggiri) 10kg', 'Ingredients', 220),
      (31, 'Chicken 8kg', 'Ingredients', 92),
      (38, 'Petrol - deliveries', 'Transport', 55),
      (45, 'Chest freezer deposit', 'Equipment', 300),
      (52, 'Fish paste (ikan tenggiri) 10kg', 'Ingredients', 215),
      (60, 'Electricity (freezer)', 'Utilities', 110),
      (68, 'Printing stickers & flyers', 'Marketing', 40),
    ];
    return [
      for (final (i, e) in items.indexed)
        Expense(
          id: 'e_$i',
          title: e.$2,
          category: e.$3,
          amount: e.$4,
          spentOn: now.subtract(Duration(days: e.$1)),
        ),
    ];
  }
}
