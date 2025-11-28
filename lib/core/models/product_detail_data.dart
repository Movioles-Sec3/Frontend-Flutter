import '../../domain/entities/product.dart';

/// Input payload for preparing product detail data off the UI thread.
class ProductInput {
  ProductInput({
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

  factory ProductInput.fromEntity(ProductEntity p) {
    return ProductInput(
      id: p.id,
      typeId: p.typeId,
      name: p.name,
      description: p.description,
      imageUrl: p.imageUrl,
      price: p.price,
      available: p.available,
    );
  }
}

/// Prepared detail data consumed by the product detail page (UI friendly).
class PreparedProductData {
  const PreparedProductData({
    required this.id,
    required this.typeId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.available,
    required this.heroTag,
  });

  final int id;
  final int typeId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool available;
  final String heroTag;

  factory PreparedProductData.fromEntity(ProductEntity p) {
    return PreparedProductData(
      id: p.id,
      typeId: p.typeId,
      name: p.name,
      description: p.description.isEmpty
          ? 'Sin descripción disponible.'
          : p.description,
      imageUrl: p.imageUrl,
      price: p.price,
      available: p.available,
      heroTag: 'product-${p.id}',
    );
  }
}

PreparedProductData prepareProductData(ProductInput input) {
  // Normalize and prepare data off the UI thread (compute runs in another isolate)
  final String description = input.description.trim().isEmpty
      ? 'Sin descripción disponible.'
      : input.description.trim();

  return PreparedProductData(
    id: input.id,
    typeId: input.typeId,
    name: input.name.trim(),
    description: description,
    imageUrl: input.imageUrl.trim(),
    price: input.price,
    available: input.available,
    heroTag: 'product-${input.id}',
  );
}
