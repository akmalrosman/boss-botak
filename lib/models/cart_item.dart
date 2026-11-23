import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity}) => CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        product: Product.fromMap(Map<String, dynamic>.from(m['product'] as Map)),
        quantity: (m['quantity'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'product': product.toMap(),
        'quantity': quantity,
      };
}
