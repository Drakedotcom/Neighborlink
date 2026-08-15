import 'package:flutter/foundation.dart';

///LuS
///neighbourhood = postal code
@immutable
class Neighborhood {
  const Neighborhood({
    required this.id,
    required this.postalCode,
    required this.cityName,
    required this.description,
    required this.createdAt,
    this.memberCount = 0,
  });

  final int id;
  final String postalCode;
  final String cityName;
  final String description;
  final DateTime createdAt;
  final int memberCount;

  String get displayName => '$postalCode $cityName';

  factory Neighborhood.fromMap(Map<String, Object?> row) {
    return Neighborhood(
      id: row['id']! as int,
      postalCode: row['postal_code']! as String,
      cityName: row['city_name']! as String,
      description: (row['description'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at']! as String),
      memberCount: (row['member_count'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'postal_code': postalCode,
    'city_name': cityName,
    'description': description,
    'created_at': createdAt.toIso8601String(),
  };

  Neighborhood copyWith({int? memberCount}) => Neighborhood(
    id: id,
    postalCode: postalCode,
    cityName: cityName,
    description: description,
    createdAt: createdAt,
    memberCount: memberCount ?? this.memberCount,
  );

  @override
  String toString() => 'Neighborhood(#$id, $displayName, $memberCount members)';
}