class OrderEntity {
  OrderEntity({
    required this.id,
    required this.total,
    required this.status,
    required this.placedAt,
    this.readyAt,
    this.deliveredAt,
    this.qr,
    this.raw,
  });

  final int id;
  final double total;
  final String status;
  final String placedAt;
  final String? readyAt;
  final String? deliveredAt;
  final Map<String, dynamic>? qr;
  final Map<String, dynamic>? raw;

  factory OrderEntity.fromJson(Map<String, dynamic> json) {
    return OrderEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      total: ((json['total'] ?? 0) as num).toDouble(),
      status: (json['estado'] ?? '').toString(),
      placedAt: (json['fecha_hora'] ?? '').toString(),
      readyAt: (json['fecha_listo'] ?? '').toString().isEmpty
          ? null
          : (json['fecha_listo'] ?? '').toString(),
      deliveredAt: (json['fecha_entregado'] ?? '').toString().isEmpty
          ? null
          : (json['fecha_entregado'] ?? '').toString(),
      qr: json['qr'] is Map<String, dynamic>
          ? (json['qr'] as Map<String, dynamic>)
          : null,
      raw: json,
    );
  }
}
