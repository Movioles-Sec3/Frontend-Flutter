class ProductEntity {
  ProductEntity({
    required this.id,
    required this.typeId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.available,
  });

  final int id;
  final int typeId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool available;

  factory ProductEntity.fromJson(Map<String, dynamic> json) {
    return ProductEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      typeId: (json['id_tipo'] as num?)?.toInt() ?? 0,
      name: (json['nombre'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      imageUrl: (json['imagen_url'] ?? '').toString(),
      price: ((json['precio'] ?? 0) as num).toDouble(),
      available: (json['disponible'] ?? true) as bool,
    );
  }
}
