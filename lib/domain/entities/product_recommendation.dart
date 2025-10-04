import 'product.dart';

class ProductType {
  ProductType({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['nombre'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
  };
}

class ProductRecommendation {
  ProductRecommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.available,
    required this.typeId,
    required this.productType,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool available;
  final int typeId;
  final ProductType productType;

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    return ProductRecommendation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['nombre'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      imageUrl: (json['imagen_url'] ?? '').toString(),
      price: ((json['precio'] ?? 0) as num).toDouble(),
      available: (json['disponible'] ?? true) as bool,
      typeId: (json['id_tipo'] as num?)?.toInt() ?? 0,
      productType: ProductType.fromJson(json['tipo_producto'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'descripcion': description,
    'imagen_url': imageUrl,
    'precio': price,
    'disponible': available,
    'id_tipo': typeId,
    'tipo_producto': productType.toJson(),
  };

  /// Convert to regular ProductEntity for compatibility
  ProductEntity toProductEntity() {
    return ProductEntity(
      id: id,
      typeId: typeId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      price: price,
      available: available,
    );
  }
}
