import 'package:boss_botak/core/analytics.dart';
import 'package:boss_botak/models/app_user.dart';
import 'package:boss_botak/models/expense.dart';
import 'package:boss_botak/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order({
  required int no,
  required double price,
  required double cost,
  required int qty,
  required DateTime at,
  String name = 'Kak Ros',
  String phone = '013-2233445',
  OrderStatus status = OrderStatus.completed,
  bool paid = true,
}) {
  final subtotal = price * qty;
  return Order(
    id: 'o$no',
    orderNo: no,
    customerName: name,
    customerPhone: phone,
    items: [
      OrderItem(
          productId: 'p1', productName: 'Otak-Otak', unitPrice: price, unitCost: cost, quantity: qty),
    ],
    subtotal: subtotal,
    deliveryFee: 0,
    discount: 0,
    total: subtotal,
    fulfilment: Fulfilment.pickup,
    paymentMethod: PaymentMethod.duitnow,
    paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
    status: status,
    source: OrderSource.whatsapp,
    createdAt: at,
  );
}

void main() {
  final now = DateTime(2026, 11, 23, 12);
  final from = ReportPeriod.week.start(now);

  test('profit & loss summary ignores cancelled orders and old data', () {
    final orders = [
      _order(no: 1, price: 12, cost: 6, qty: 10, at: now.subtract(const Duration(days: 1))),
      _order(no: 2, price: 15, cost: 8, qty: 4, at: now, paid: false),
      _order(
          no: 3,
          price: 12,
          cost: 6,
          qty: 5,
          at: now,
          status: OrderStatus.cancelled),
      _order(no: 4, price: 12, cost: 6, qty: 50, at: now.subtract(const Duration(days: 40))),
    ];
    final expenses = [
      Expense(id: 'e1', title: 'Fish', category: 'Ingredients', amount: 50, spentOn: now),
      Expense(
          id: 'e2',
          title: 'Old',
          category: 'Other',
          amount: 999,
          spentOn: now.subtract(const Duration(days: 60))),
    ];

    final s = Analytics.summarise(orders: orders, expenses: expenses, from: from);
    expect(s.orderCount, 2);
    expect(s.revenue, 180); // 120 + 60
    expect(s.costOfGoods, 92); // 60 + 32
    expect(s.grossProfit, 88);
    expect(s.expenses, 50);
    expect(s.netProfit, 38);
    expect(s.unpaidAmount, 60);
    expect(s.itemsSold, 14);
  });

  test('weekly sales series has 7 points and puts sales on the right day', () {
    final series = Analytics.salesSeries(
      [_order(no: 1, price: 10, cost: 5, qty: 2, at: now)],
      ReportPeriod.week,
      now,
    );
    expect(series, hasLength(7));
    expect(series.last.value, 20);
    expect(series.first.value, 0);
  });

  test('yearly series groups by month', () {
    final series = Analytics.salesSeries(
      [_order(no: 1, price: 10, cost: 5, qty: 2, at: now)],
      ReportPeriod.year,
      now,
    );
    expect(series, hasLength(12));
    expect(series.last.label, 'Nov');
    expect(series.last.value, 20);
  });

  test('customer database merges app users and WhatsApp buyers by phone', () {
    final profiles = [
      const AppUser(id: 'u1', email: 'ros@x.my', fullName: 'Rosnah', phone: '+60132233445'),
      const AppUser(id: 'u2', email: 'boss@x.my', fullName: 'Boss', role: UserRole.admin),
    ];
    final orders = [
      _order(no: 1, price: 10, cost: 5, qty: 2, at: now),
      _order(no: 2, price: 10, cost: 5, qty: 3, at: now.subtract(const Duration(days: 2))),
      _order(no: 3, price: 10, cost: 5, qty: 1, at: now, name: 'Mei Ling', phone: '016-5566778'),
    ];
    final list = Analytics.customers(orders, profiles);
    expect(list, hasLength(2)); // admin excluded
    final ros = list.first;
    expect(ros.name, 'Rosnah');
    expect(ros.isRegistered, isTrue);
    expect(ros.orderCount, 2);
    expect(ros.totalSpent, 50);
    expect(ros.lastOrder, now);
  });
}
