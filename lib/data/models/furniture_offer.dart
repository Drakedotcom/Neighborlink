import 'package:flutter/foundation.dart';

import '../../ui/widgets/status_badge.dart';

/// Furniture offer process: verfügbar -> reserviert -> vergeben.
enum FurnitureStatus {
  available('available', 'Verfügbar', StatusTone.available),
  reserved('reserved', 'Reserviert', StatusTone.reserved),
  givenAway('given_away', 'Vergeben', StatusTone.closed);

  const FurnitureStatus(this.storageValue, this.label, this.tone);

  final String storageValue;
  final String label;
  final StatusTone tone;

  static FurnitureStatus fromStorage(String? value) => FurnitureStatus.values
      .firstWhere(
        (status) => status.storageValue == value,
        orElse: () => FurnitureStatus.available,
      );
}

/// State of a single request a neighbour sent for an item.
enum FurnitureRequestStatus {
  pending('pending', 'Offen'),
  accepted('accepted', 'Angenommen'),
  declined('declined', 'Abgelehnt');

  const FurnitureRequestStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static FurnitureRequestStatus fromStorage(String? value) =>
      FurnitureRequestStatus.values.firstWhere(
        (status) => status.storageValue == value,
        orElse: () => FurnitureRequestStatus.pending,
      );
}

/// LuL An item somebody wants to give away.
@immutable
class FurnitureOffer {
  const FurnitureOffer({
    required this.id,
    required this.neighborhoodId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.conditionLabel,
    required this.status,
    required this.createdAt,
    this.reservedById,
    this.ownerName = '',
    this.reservedByName,
    this.openRequestCount = 0,
    this.currentUserHasRequested = false,
  });

  final int id;
  final int neighborhoodId;
  final int ownerId;
  final String title;
  final String description;

  /// e.g. neuwertig, gebraucht.
  final String conditionLabel;

  final FurnitureStatus status;
  final int? reservedById;
  final DateTime createdAt;

  // --- Derived fields --------------------------------------------------------
  final String ownerName;
  final String? reservedByName;
  final int openRequestCount;
  final bool currentUserHasRequested;

  bool get isAvailable => status == FurnitureStatus.available;
  bool get isClosed => status == FurnitureStatus.givenAway;
  bool isOwnedBy(int userId) => ownerId == userId;

  factory FurnitureOffer.fromMap(Map<String, Object?> row) => FurnitureOffer(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    ownerId: row['owner_id']! as int,
    title: row['title']! as String,
    description: row['description']! as String,
    conditionLabel: row['condition_label']! as String,
    status: FurnitureStatus.fromStorage(row['status'] as String?),
    reservedById: row['reserved_by_id'] as int?,
    createdAt: DateTime.parse(row['created_at']! as String),
    ownerName: (row['owner_name'] as String?) ?? '',
    reservedByName: row['reserved_by_name'] as String?,
    openRequestCount: (row['open_request_count'] as int?) ?? 0,
    currentUserHasRequested: ((row['has_requested'] as int?) ?? 0) == 1,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'owner_id': ownerId,
    'title': title,
    'description': description,
    'condition_label': conditionLabel,
    'status': status.storageValue,
    'reserved_by_id': reservedById,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'FurnitureOffer(#$id, $title, ${status.storageValue})';
}

/// A request a neighbour sent for a furniture offer.
@immutable
class FurnitureRequest {
  const FurnitureRequest({
    required this.id,
    required this.offerId,
    required this.requesterId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.requesterName = '',
  });

  final int id;
  final int offerId;
  final int requesterId;
  final String message;
  final FurnitureRequestStatus status;
  final DateTime createdAt;
  final String requesterName;

  factory FurnitureRequest.fromMap(Map<String, Object?> row) => FurnitureRequest(
    id: row['id']! as int,
    offerId: row['furniture_offer_id']! as int,
    requesterId: row['requester_id']! as int,
    message: (row['message'] as String?) ?? '',
    status: FurnitureRequestStatus.fromStorage(row['status'] as String?),
    createdAt: DateTime.parse(row['created_at']! as String),
    requesterName: (row['requester_name'] as String?) ?? '',
  );
}
