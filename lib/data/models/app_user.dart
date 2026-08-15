import 'package:flutter/foundation.dart';

///LuS
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.streetAddress,
    required this.postalCode,
    required this.neighborhoodId,
    required this.aboutMe,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String email;
  final String streetAddress;
  final String postalCode;
  final int neighborhoodId;
  final String aboutMe;
  final DateTime createdAt;

  ///used by avatar widget
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.firstLetters(2);
    return '${parts.first.firstLetters(1)}${parts.last.firstLetters(1)}'
        .toUpperCase();
  }

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromMap(Map<String, Object?> row) {
    return AppUser(
      id: row['id']! as int,
      fullName: row['full_name']! as String,
      email: row['email']! as String,
      streetAddress: row['street_address']! as String,
      postalCode: row['postal_code']! as String,
      neighborhoodId: row['neighborhood_id']! as int,
      aboutMe: (row['about_me'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }

  ///w/o credentials
  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'full_name': fullName,
    'email': email,
    'street_address': streetAddress,
    'postal_code': postalCode,
    'neighborhood_id': neighborhoodId,
    'about_me': aboutMe,
    'created_at': createdAt.toIso8601String(),
  };

  AppUser copyWith({String? fullName, String? streetAddress, String? aboutMe}) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      streetAddress: streetAddress ?? this.streetAddress,
      postalCode: postalCode,
      neighborhoodId: neighborhoodId,
      aboutMe: aboutMe ?? this.aboutMe,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AppUser(#$id, $fullName, $email)';
}

///helper, first x chars
extension on String {
  String firstLetters(int count) =>
      length <= count ? toUpperCase() : substring(0, count).toUpperCase();
}