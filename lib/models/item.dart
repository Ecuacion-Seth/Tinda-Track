class Item {
  final String id;
  final String name;
  final String categoryId;
  final double price;
  final int quantity;
  final String? barcode;
  final String? imagePath;
  final int lowStockThreshold;
  final String updatedAt;

  Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.quantity,
    this.barcode,
    this.imagePath,
    this.lowStockThreshold = 5,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'price': price,
      'quantity': quantity,
      'barcode': barcode,
      'image_path': imagePath,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': updatedAt,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      categoryId: map['category_id'],
      price: map['price'],
      quantity: map['quantity'],
      barcode: map['barcode'],
      imagePath: map['image_path'],
      lowStockThreshold: map['low_stock_threshold'],
      updatedAt: map['updated_at'],
    );
  }

  Item copyWith({
    String? id,
    String? name,
    String? categoryId,
    double? price,
    int? quantity,
    String? barcode,
    String? imagePath,
    int? lowStockThreshold,
    String? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}