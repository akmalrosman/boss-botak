import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Reporting period used by the financial dashboard.
enum ReportPeriod {
  week('7 days'),
  month('30 days'),
  year('12 months');

  const ReportPeriod(this.label);
  final String label;

  DateTime start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      week => today.subtract(const Duration(days: 6)),
      month => today.subtract(const Duration(days: 29)),
      year => DateTime(now.year - 1, now.month + 1, 1),
    };
  }
}

class FinanceSummary {
  const FinanceSummary({
    required this.revenue,
    required this.costOfGoods,
    required this.expenses,
    required this.orderCount,
    required this.unpaidAmount,
    required this.itemsSold,
  });

  /// Total billed to customers (incl. delivery fees) for non-cancelled orders.
  final double revenue;
  final double costOfGoods;
  final double expenses;
  final int orderCount;
  final double unpaidAmount;
  final int itemsSold;

  double get grossProfit => revenue - costOfGoods;
  double get netProfit => grossProfit - expenses;
  double get averageOrderValue => orderCount == 0 ? 0 : revenue / orderCount;
  double get profitMargin => revenue == 0 ? 0 : netProfit / revenue;
}

class SalesPoint {
  const SalesPoint(this.label, this.value);
  final String label;
  final double value;
}

class ProductSales {
  const ProductSales(this.name, this.quantity, this.revenue);
  final String name;
  final int quantity;
  final double revenue;
}

class CustomerSummary {
  const CustomerSummary({
    required this.name,
    required this.phone,
    required this.orderCount,
    required this.totalSpent,
    this.lastOrder,
    this.email,
    this.address = '',
    this.isRegistered = false,
  });

  final String name;
  final String phone;
  final String? email;
  final String address;
  final int orderCount;
  final double totalSpent;
  final DateTime? lastOrder;
  final bool isRegistered;
}

class Analytics {
  Analytics._();

  static bool _inRange(DateTime d, DateTime from, DateTime? to) {
    final local = d.toLocal();
    return !local.isBefore(from) && (to == null || local.isBefore(to));
  }

  static FinanceSummary summarise({
    required List<Order> orders,
    required List<Expense> expenses,
    required DateTime from,
    DateTime? to,
  }) {
    var revenue = 0.0, cogs = 0.0, unpaid = 0.0, exp = 0.0;
    var count = 0, items = 0;
    for (final o in orders) {
      if (!o.countsAsSale || !_inRange(o.createdAt, from, to)) continue;
      revenue += o.total;
      cogs += o.costOfGoods;
      items += o.itemCount;
      count++;
      if (!o.isPaid) unpaid += o.total;
    }
    for (final e in expenses) {
      if (_inRange(e.spentOn, from, to)) exp += e.amount;
    }
    return FinanceSummary(
      revenue: revenue,
      costOfGoods: cogs,
      expenses: exp,
      orderCount: count,
      unpaidAmount: unpaid,
      itemsSold: items,
    );
  }

  /// Sales grouped per day (week/month) or per month (year).
  static List<SalesPoint> salesSeries(
    List<Order> orders,
    ReportPeriod period,
    DateTime now,
  ) {
    final start = period.start(now);
    if (period == ReportPeriod.year) {
      final buckets = <String, double>{};
      final labels = <String>[];
      for (var i = 0; i < 12; i++) {
        final m = DateTime(start.year, start.month + i, 1);
        final key = '${m.year}-${m.month}';
        buckets[key] = 0;
        labels.add(key);
      }
      for (final o in orders) {
        if (!o.countsAsSale) continue;
        final d = o.createdAt.toLocal();
        final key = '${d.year}-${d.month}';
        if (buckets.containsKey(key)) buckets[key] = buckets[key]! + o.total;
      }
      return [
        for (final k in labels)
          SalesPoint(
            DateFormat('MMM').format(
              DateTime(int.parse(k.split('-')[0]), int.parse(k.split('-')[1])),
            ),
            buckets[k]!,
          ),
      ];
    }

    final days = period == ReportPeriod.week ? 7 : 30;
    final values = List<double>.filled(days, 0);
    for (final o in orders) {
      if (!o.countsAsSale) continue;
      final d = o.createdAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < days) values[idx] += o.total;
    }
    return [
      for (var i = 0; i < days; i++)
        SalesPoint(
          period == ReportPeriod.week
              ? DateFormat('E').format(start.add(Duration(days: i)))
              : DateFormat('d/M').format(start.add(Duration(days: i))),
          values[i],
        ),
    ];
  }

  static List<ProductSales> topProducts(
    List<Order> orders, {
    required DateTime from,
    int limit = 5,
  }) {
    final qty = <String, int>{};
    final rev = <String, double>{};
    for (final o in orders) {
      if (!o.countsAsSale || !_inRange(o.createdAt, from, null)) continue;
      for (final i in o.items) {
        qty[i.productName] = (qty[i.productName] ?? 0) + i.quantity;
        rev[i.productName] = (rev[i.productName] ?? 0) + i.lineTotal;
      }
    }
    final list = qty.keys
        .map((k) => ProductSales(k, qty[k]!, rev[k]!))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  static Map<String, double> expensesByCategory(
    List<Expense> expenses, {
    required DateTime from,
  }) {
    final map = <String, double>{};
    for (final e in expenses) {
      if (!_inRange(e.spentOn, from, null)) continue;
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  static List<Product> lowStock(List<Product> products) =>
      products.where((p) => p.isActive && p.isLowStock).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  /// Builds the customer database from registered profiles and from every
  /// order (including WhatsApp / walk-in customers who never registered).
  /// Customers are matched by phone number.
  static List<CustomerSummary> customers(
    List<Order> orders,
    List<AppUser> profiles,
  ) {
    String key(String phone, String name) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final normalised = digits.startsWith('60') ? digits.substring(1) : digits;
      return normalised.isEmpty ? 'name:${name.toLowerCase()}' : normalised;
    }

    final map = <String, CustomerSummary>{};
    for (final p in profiles.where((p) => !p.isAdmin)) {
      map[key(p.phone, p.fullName)] = CustomerSummary(
        name: p.fullName,
        phone: p.phone,
        email: p.email,
        address: p.address,
        orderCount: 0,
        totalSpent: 0,
        isRegistered: true,
      );
    }
    for (final o in orders) {
      if (!o.countsAsSale) continue;
      final k = key(o.customerPhone, o.customerName);
      final prev = map[k];
      final last = prev?.lastOrder;
      map[k] = CustomerSummary(
        name: prev?.name ?? o.customerName,
        phone: prev?.phone.isNotEmpty == true ? prev!.phone : o.customerPhone,
        email: prev?.email,
        address: (prev?.address.isNotEmpty ?? false) ? prev!.address : o.address,
        orderCount: (prev?.orderCount ?? 0) + 1,
        totalSpent: (prev?.totalSpent ?? 0) + o.total,
        lastOrder:
            last == null || o.createdAt.isAfter(last) ? o.createdAt : last,
        isRegistered: prev?.isRegistered ?? false,
      );
    }
    return map.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  }
}
