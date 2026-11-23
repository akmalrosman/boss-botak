/// Business settings for Boss Botak. Change these to match the real shop.
class ShopConfig {
  ShopConfig._();

  static const String name = 'Boss Botak';
  static const String tagline = 'Rasa Sedap, Pasti Nak Lagi!';

  /// WhatsApp / phone number in international format (no + or spaces).
  static const String whatsappNumber = '60198921449';
  static const String displayPhone = '019-892 1449';

  /// Pickup point / kitchen location used to calculate delivery distance.
  /// TODO(team): replace with Boss Botak's actual kitchen coordinates.
  static const double shopLat = 1.8548;
  static const double shopLng = 102.9325;
  static const String shopAddress = 'Batu Pahat, Johor';

  static const List<String> productCategories = ['Otak-Otak', 'Pepes', 'Combo'];

  static const List<String> expenseCategories = [
    'Ingredients',
    'Packaging',
    'Transport',
    'Utilities',
    'Marketing',
    'Equipment',
    'Other',
  ];
}
