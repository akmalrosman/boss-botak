import 'dart:math' as math;

/// Pricing & monetisation rules.
///
/// The same rules are enforced again on the server inside the `place_order`
/// SQL function (supabase/schema.sql) so the client cannot tamper with them.
class PricingPolicy {
  PricingPolicy._();

  /// Delivery: flat fee for the first [includedKm], then [perKm] per extra km.
  static const double baseDeliveryFee = 5.0;
  static const double includedKm = 5.0;
  static const double perKm = 1.0;

  /// "Area berdekatan" - furthest distance Boss Botak will deliver.
  static const double maxDeliveryKm = 25.0;

  /// Upsell: free delivery when the basket reaches this amount.
  static const double freeDeliveryThreshold = 150.0;

  /// Open House bulk deal: [bulkDiscountRate] off when subtotal >= threshold.
  static const double bulkDiscountThreshold = 300.0;
  static const double bulkDiscountRate = 0.05;

  static bool isDeliverable(double distanceKm) =>
      distanceKm >= 0 && distanceKm <= maxDeliveryKm;

  static double deliveryFee({
    required double distanceKm,
    required double subtotal,
  }) {
    if (subtotal >= freeDeliveryThreshold) return 0;
    final extraKm = math.max(0, distanceKm - includedKm);
    return baseDeliveryFee + extraKm.ceil() * perKm;
  }

  static double discount(double subtotal) {
    if (subtotal < bulkDiscountThreshold) return 0;
    return roundMoney(subtotal * bulkDiscountRate);
  }

  static OrderTotals totals({
    required double subtotal,
    required bool delivery,
    double distanceKm = 0,
  }) {
    final fee =
        delivery ? deliveryFee(distanceKm: distanceKm, subtotal: subtotal) : 0.0;
    final disc = discount(subtotal);
    return OrderTotals(
      subtotal: roundMoney(subtotal),
      deliveryFee: roundMoney(fee),
      discount: disc,
      total: roundMoney(subtotal - disc + fee),
    );
  }

  static double roundMoney(double v) => (v * 100).roundToDouble() / 100;
}

class OrderTotals {
  const OrderTotals({
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
}

/// Great-circle distance between two coordinates in kilometres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
