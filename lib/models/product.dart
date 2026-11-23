class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    this.description = '',
    this.unit = '1 pack',
    this.lowStockThreshold = 10,
    this.imageUrl = '',
    this.isActive = true,
    this.createdAt,
  });

  /// Empty id means "not saved yet".
  final String id;
  final String name;
  final String description;
  final String category;
  final String unit;
  final double price;

  /// Cost price per unit (ingredients + packaging) used for profit reports.
  final double cost;
  final int stock;
  final int lowStockThreshold;

  /// `asset:<name>` for bundled photos, otherwise an https URL.
  final String imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  bool get isNew => id.isEmpty;
  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock <= lowStockThreshold;
  double get margin => price - cost;

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? unit,
    double? price,
    double? cost,
    int? stock,
    int? lowStockThreshold,
    String? imageUrl,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String,
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Other',
        unit: (m['unit'] as String?) ?? '1 pack',
        price: (m['price'] as num).toDouble(),
        cost: ((m['cost'] as num?) ?? 0).toDouble(),
        stock: (m['stock'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (m['low_stock_threshold'] as num?)?.toInt() ?? 10,
        imageUrl: (m['image_url'] as String?) ?? '',
        isActive: (m['is_active'] as bool?) ?? true,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.parse(m['created_at'] as String),
      );

  /// Map for insert/update. The id and created_at are managed by the database.
  Map<String, dynamic> toWriteMap() => {
        'name': name,
        'description': description,
        'category': category,
        'unit': unit,
        'price': price,
        'cost': cost,
        'stock': stock,
        'low_stock_threshold': lowStockThreshold,
        'image_url': imageUrl,
        'is_active': isActive,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        ...toWriteMap(),
        'created_at': createdAt?.toIso8601String(),
      };
}
