class UserEntity {
  UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.balance,
  });

  final int id;
  final String name;
  final String email;
  final num balance;

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['nombre'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      balance: (json['saldo'] ?? 0) as num,
    );
  }
}
