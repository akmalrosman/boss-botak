import 'package:flutter/material.dart';

enum OrderStatus {
  pending('Pending', Icons.schedule),
  confirmed('Confirmed', Icons.thumb_up_alt_outlined),
  preparing('Preparing', Icons.soup_kitchen_outlined),
  ready('Ready', Icons.inventory_2_outlined),
  completed('Completed', Icons.check_circle_outline),
  cancelled('Cancelled', Icons.cancel_outlined);

  const OrderStatus(this.label, this.icon);
  final String label;
  final IconData icon;

  static OrderStatus parse(String? v) =>
      OrderStatus.values.firstWhere((s) => s.name == v, orElse: () => pending);

  /// Normal forward flow of an order. Cancelled is handled separately.
  static const flow = [pending, confirmed, preparing, ready, completed];

  bool get isOpen => this != completed && this != cancelled;

  OrderStatus? get next {
    final i = flow.indexOf(this);
    if (i < 0 || i == flow.length - 1) return null;
    return flow[i + 1];
  }
}

enum Fulfilment {
  pickup('Self pickup', Icons.storefront_outlined),
  delivery('Delivery', Icons.local_shipping_outlined);

  const Fulfilment(this.label, this.icon);
  final String label;
  final IconData icon;

  static Fulfilment parse(String? v) => v == 'delivery' ? delivery : pickup;
}

/// Common Malaysian payment methods.
enum PaymentMethod {
  duitnow('DuitNow QR', Icons.qr_code_2),
  fpx('FPX Online Banking', Icons.account_balance_outlined);

  const PaymentMethod(this.label, this.icon);
  final String label;
  final IconData icon;

  String get description => switch (this) {
        duitnow => 'Scan the QR with any banking app or e-wallet, then upload your receipt',
        fpx => 'Pay directly from your bank account',
      };

  static PaymentMethod parse(String? v) =>
      v == 'fpx' ? fpx : duitnow; // older values (cash/transfer/card) fall back to DuitNow
}

enum PaymentStatus {
  unpaid('Unpaid'),

  /// DuitNow receipt uploaded, waiting for the owner to check it.
  pendingVerification('Verifying'),
  paid('Paid');

  const PaymentStatus(this.label);
  final String label;

  String get dbValue => this == pendingVerification ? 'pending_verification' : name;

  static PaymentStatus parse(String? v) => switch (v) {
        'paid' => paid,
        'pending_verification' => pendingVerification,
        _ => unpaid,
      };
}

/// Where the order came from. WhatsApp / walk-in sales are recorded by the
/// owner so ALL sales end up in one place for reporting.
enum OrderSource {
  app('App'),
  whatsapp('WhatsApp'),
  walkIn('Walk-in');

  const OrderSource(this.label);
  final String label;

  String get dbValue => this == walkIn ? 'walk_in' : name;

  static OrderSource parse(String? v) => switch (v) {
        'whatsapp' => whatsapp,
        'walk_in' => walkIn,
        _ => app,
      };
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.unitCost,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final double unitCost;
  final int quantity;

  double get lineTotal => unitPrice * quantity;
  double get lineCost => unitCost * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: (m['product_id'] as String?) ?? '',
        productName: m['product_name'] as String,
        unitPrice: (m['unit_price'] as num).toDouble(),
        unitCost: ((m['unit_cost'] as num?) ?? 0).toDouble(),
        quantity: (m['quantity'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'unit_price': unitPrice,
        'unit_cost': unitCost,
        'quantity': quantity,
      };
}

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.fulfilment,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.source,
    required this.createdAt,
    this.customerId,
    this.address = '',
    this.lat,
    this.lng,
    this.distanceKm,
    this.scheduledFor,
    this.notes = '',
    this.paymentRef,
    this.receiptUrl,
  });

  final String id;
  final int orderNo;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final Fulfilment fulfilment;
  final String address;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final DateTime? scheduledFor;
  final String notes;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentRef;

  /// DuitNow receipt: storage path (cloud) or data URI (demo mode).
  final String? receiptUrl;
  final OrderStatus status;
  final OrderSource source;
  final DateTime createdAt;

  String get code => 'BB-${orderNo.toString().padLeft(4, '0')}';
  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get awaitingVerification => paymentStatus == PaymentStatus.pendingVerification;
  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  /// The customer can still pay (not paid, not waiting for a check, not cancelled).
  bool get canPay => paymentStatus == PaymentStatus.unpaid && status != OrderStatus.cancelled;
  bool get countsAsSale => status != OrderStatus.cancelled;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get costOfGoods => items.fold(0.0, (sum, i) => sum + i.lineCost);

  /// Product revenue after discount (delivery fee excluded).
  double get netProductSales => subtotal - discount;

  Order copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    String? paymentRef,
    String? receiptUrl,
    bool clearReceipt = false,
  }) {
    return Order(
      id: id,
      orderNo: orderNo,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      total: total,
      fulfilment: fulfilment,
      address: address,
      lat: lat,
      lng: lng,
      distanceKm: distanceKm,
      scheduledFor: scheduledFor,
      notes: notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentRef: paymentRef ?? this.paymentRef,
      receiptUrl: clearReceipt ? null : (receiptUrl ?? this.receiptUrl),
      status: status ?? this.status,
      source: source,
      createdAt: createdAt,
    );
  }

  factory Order.fromMap(Map<String, dynamic> m) {
    final rawItems = (m['order_items'] ?? m['items']) as List<dynamic>? ?? [];
    return Order(
      id: m['id'] as String,
      orderNo: (m['order_no'] as num).toInt(),
      customerId: m['customer_id'] as String?,
      customerName: (m['customer_name'] as String?) ?? 'Customer',
      customerPhone: (m['customer_phone'] as String?) ?? '',
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: (m['subtotal'] as num).toDouble(),
      deliveryFee: ((m['delivery_fee'] as num?) ?? 0).toDouble(),
      discount: ((m['discount'] as num?) ?? 0).toDouble(),
      total: (m['total'] as num).toDouble(),
      fulfilment: Fulfilment.parse(m['fulfilment'] as String?),
      address: (m['address'] as String?) ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      distanceKm: (m['distance_km'] as num?)?.toDouble(),
      scheduledFor: m['scheduled_for'] == null
          ? null
          : DateTime.parse(m['scheduled_for'] as String),
      notes: (m['notes'] as String?) ?? '',
      paymentMethod: PaymentMethod.parse(m['payment_method'] as String?),
      paymentStatus: PaymentStatus.parse(m['payment_status'] as String?),
      paymentRef: m['payment_ref'] as String?,
      receiptUrl: m['receipt_url'] as String?,
      status: OrderStatus.parse(m['status'] as String?),
      source: OrderSource.parse(m['source'] as String?),
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_no': orderNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'total': total,
        'fulfilment': fulfilment.name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'distance_km': distanceKm,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'notes': notes,
        'payment_method': paymentMethod.name,
        'payment_status': paymentStatus.dbValue,
        'payment_ref': paymentRef,
        'receipt_url': receiptUrl,
        'status': status.name,
        'source': source.dbValue,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Everything needed to place a new order. Prices are re-read from the
/// database on the server, so only product ids and quantities are trusted.
class OrderDraft {
  const OrderDraft({
    required this.lines,
    required this.fulfilment,
    required this.paymentMethod,
    this.address = '',
    this.lat,
    this.lng,
    this.scheduledFor,
    this.notes = '',
    this.customerName,
    this.customerPhone,
    this.source = OrderSource.app,
    this.markPaid = false,
  });

  /// productId -> quantity
  final Map<String, int> lines;
  final Fulfilment fulfilment;
  final PaymentMethod paymentMethod;
  final String address;
  final double? lat;
  final double? lng;
  final DateTime? scheduledFor;
  final String notes;

  /// Only used when the owner records a WhatsApp / walk-in sale.
  final String? customerName;
  final String? customerPhone;
  final OrderSource source;
  final bool markPaid;
}
