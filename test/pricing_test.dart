import 'package:boss_botak/core/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Delivery fee', () {
    test('flat fee within the included distance', () {
      expect(PricingPolicy.deliveryFee(distanceKm: 3.2, subtotal: 40), 5);
      expect(PricingPolicy.deliveryFee(distanceKm: 5, subtotal: 40), 5);
    });

    test('adds RM1 per started km beyond 5 km', () {
      expect(PricingPolicy.deliveryFee(distanceKm: 5.1, subtotal: 40), 6);
      expect(PricingPolicy.deliveryFee(distanceKm: 12.4, subtotal: 40), 13);
    });

    test('free delivery from RM150', () {
      expect(PricingPolicy.deliveryFee(distanceKm: 20, subtotal: 150), 0);
    });

    test('delivery radius', () {
      expect(PricingPolicy.isDeliverable(24.9), isTrue);
      expect(PricingPolicy.isDeliverable(25.1), isFalse);
    });
  });

  group('Order totals', () {
    test('pickup has no delivery fee or discount under RM300', () {
      final t = PricingPolicy.totals(subtotal: 60, delivery: false);
      expect(t.deliveryFee, 0);
      expect(t.discount, 0);
      expect(t.total, 60);
    });

    test('5% Open House discount from RM300 and free delivery', () {
      final t = PricingPolicy.totals(subtotal: 320, delivery: true, distanceKm: 10);
      expect(t.discount, 16);
      expect(t.deliveryFee, 0);
      expect(t.total, 304);
    });

    test('delivery fee is added to total', () {
      final t = PricingPolicy.totals(subtotal: 50, delivery: true, distanceKm: 7.5);
      expect(t.deliveryFee, 8);
      expect(t.total, 58);
    });
  });

  test('haversine distance Batu Pahat -> Johor Bahru is ~ 100 km', () {
    final km = haversineKm(1.8548, 102.9325, 1.4927, 103.7414);
    expect(km, inInclusiveRange(95, 105));
  });
}
