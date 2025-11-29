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
    this.note = '',
    this.timesOrdered = 0,
  });

  final int id;
  final int typeId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool available;
  final String note;
  final int timesOrdered;

  factory ProductInput.fromEntity(ProductEntity p) {
    return ProductInput(
      id: p.id,
      typeId: p.typeId,
      name: p.name,
      description: p.description,
      imageUrl: p.imageUrl,
      price: p.price,
      available: p.available,
      note: '',
      timesOrdered: 0,
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
    this.note = '',
    this.timesOrdered = 0,
  });

  final int id;
  final int typeId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool available;
  final String heroTag;
  final String note;
  final int timesOrdered;

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
      note: '',
      timesOrdered: 0,
    );
  }

  PreparedProductData copyWith({
    int? id,
    int? typeId,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    bool? available,
    String? heroTag,
    String? note,
    int? timesOrdered,
  }) {
    return PreparedProductData(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      available: available ?? this.available,
      heroTag: heroTag ?? this.heroTag,
      note: note ?? this.note,
      timesOrdered: timesOrdered ?? this.timesOrdered,
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
    note: input.note,
    timesOrdered: input.timesOrdered,
  );
}
