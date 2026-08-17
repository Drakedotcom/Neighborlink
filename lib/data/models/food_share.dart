import 'package:flutter/foundation.dart';

import '../../ui/widgets/status_badge.dart';

/// Food offer process: verfügbar -> reserviert -> abgeholt.
enum FoodShareStatus {
  available('available', 'Verfügbar', StatusTone.available),
  reserved('reserved', 'Reserviert', StatusTone.reserved),
  pickedUp('picked_up', 'Abgeholt', StatusTone.closed);

  const FoodShareStatus(this.storageValue, this.label, this.tone);

  final String storageValue;
  final String label;
  final StatusTone tone;

  static FoodShareStatus fromStorage(String? value) => FoodShareStatus.values
      .firstWhere(
        (status) => status.storageValue == value,
        orElse: () => FoodShareStatus.available,
      );
}

/// Share food item
@immutable
class FoodShare {
  const FoodShare({
    required this.id,
    required this.neighborhoodId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.quantity,
    required this.expiresOn,
    required this.status,
    required this.createdAt,
    this.reservedById,
    this.ownerName = '',
    this.reservedByName,
    this.interestedCount = 0,
    this.currentUserIsInterested = false,
  });

  final int id;
  final int neighborhoodId;
  final int ownerId;
  final String title;
  final String description;

  /// Free text such as x kg / x pieces -> neighbours describe amounts differently.
  final String quantity;

  /// Best-before date in ISO format
  final String expiresOn;

  final FoodShareStatus status;
  final int? reservedById;
  final DateTime createdAt;

  // --- Derived fields coming from JOINs / aggregate sub-selects -------------
  final String ownerName;
  final String? reservedByName;
  final int interestedCount;
  final bool currentUserIsInterested;

  bool get isAvailable => status == FoodShareStatus.available;
  bool get isReserved => status == FoodShareStatus.reserved;
  bool get isClosed => status == FoodShareStatus.pickedUp;

  bool isOwnedBy(int userId) => ownerId == userId;
  bool isReservedBy(int userId) => reservedById == userId;

  factory FoodShare.fromMap(Map<String, Object?> row) => FoodShare(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    ownerId: row['owner_id']! as int,
    title: row['title']! as String,
    description: row['description']! as String,
    quantity: row['quantity']! as String,
    expiresOn: row['expires_on']! as String,
    status: FoodShareStatus.fromStorage(row['status'] as String?),
    reservedById: row['reserved_by_id'] as int?,
    createdAt: DateTime.parse(row['created_at']! as String),
    ownerName: (row['owner_name'] as String?) ?? '',
    reservedByName: row['reserved_by_name'] as String?,
    interestedCount: (row['interested_count'] as int?) ?? 0,
    currentUserIsInterested: ((row['is_interested'] as int?) ?? 0) == 1,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'owner_id': ownerId,
    'title': title,
    'description': description,
    'quantity': quantity,
    'expires_on': expiresOn,
    'status': status.storageValue,
    'reserved_by_id': reservedById,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'FoodShare(#$id, $title, ${status.storageValue})';
}
