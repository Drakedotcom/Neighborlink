import 'package:flutter/foundation.dart';

import '../../ui/widgets/status_badge.dart';

/// Status of care request.
enum CareStatus {
  open('open', 'Offen', StatusTone.available),
  covered('covered', 'Übernommen', StatusTone.closed);

  const CareStatus(this.storageValue, this.label, this.tone);

  final String storageValue;
  final String label;
  final StatusTone tone;

  static CareStatus fromStorage(String? value) => CareStatus.values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => CareStatus.open,
  );
}

/// LuL Help offer of neighbour.
@immutable
class CareOffer {
  const CareOffer({
    required this.id,
    required this.requestId,
    required this.helperId,
    required this.message,
    required this.createdAt,
    this.helperName = '',
  });

  final int id;
  final int requestId;
  final int helperId;
  final String message;
  final DateTime createdAt;
  final String helperName;

  factory CareOffer.fromMap(Map<String, Object?> row) => CareOffer(
    id: row['id']! as int,
    requestId: row['request_id']! as int,
    helperId: row['helper_id']! as int,
    message: (row['message'] as String?) ?? '',
    createdAt: DateTime.parse(row['created_at']! as String),
    helperName: (row['helper_name'] as String?) ?? '',
  );
}

/// LuL request for child care.
@immutable
class ChildcareRequest {
  const ChildcareRequest({
    required this.id,
    required this.neighborhoodId,
    required this.requesterId,
    required this.careDate,
    required this.careTime,
    required this.description,
    required this.status,
    required this.createdAt,
    this.requesterName = '',
    this.offerCount = 0,
    this.currentUserHasOffered = false,
  });

  final int id;
  final int neighborhoodId;
  final int requesterId;

  /// ISO date.
  final String careDate;

  /// Free text time span.
  final String careTime;

  final String description;
  final CareStatus status;
  final DateTime createdAt;

  final String requesterName;
  final int offerCount;
  final bool currentUserHasOffered;

  bool get isOpen => status == CareStatus.open;
  bool isCreatedBy(int userId) => requesterId == userId;

  factory ChildcareRequest.fromMap(Map<String, Object?> row) => ChildcareRequest(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    requesterId: row['requester_id']! as int,
    careDate: row['care_date']! as String,
    careTime: row['care_time']! as String,
    description: row['description']! as String,
    status: CareStatus.fromStorage(row['status'] as String?),
    createdAt: DateTime.parse(row['created_at']! as String),
    requesterName: (row['requester_name'] as String?) ?? '',
    offerCount: (row['offer_count'] as int?) ?? 0,
    currentUserHasOffered: ((row['has_offered'] as int?) ?? 0) == 1,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'requester_id': requesterId,
    'care_date': careDate,
    'care_time': careTime,
    'description': description,
    'status': status.storageValue,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'ChildcareRequest(#$id, $careDate, ${status.storageValue})';
}

/// A request for pet care.
@immutable
class PetcareRequest {
  const PetcareRequest({
    required this.id,
    required this.neighborhoodId,
    required this.requesterId,
    required this.petType,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.status,
    required this.createdAt,
    this.requesterName = '',
    this.offerCount = 0,
    this.currentUserHasOffered = false,
  });

  final int id;
  final int neighborhoodId;
  final int requesterId;

  final String petType;

  final String startDate;
  final String endDate;

  final String description;
  final CareStatus status;
  final DateTime createdAt;

  final String requesterName;
  final int offerCount;
  final bool currentUserHasOffered;

  bool get isOpen => status == CareStatus.open;
  bool isCreatedBy(int userId) => requesterId == userId;

  factory PetcareRequest.fromMap(Map<String, Object?> row) => PetcareRequest(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    requesterId: row['requester_id']! as int,
    petType: row['pet_type']! as String,
    startDate: row['start_date']! as String,
    endDate: row['end_date']! as String,
    description: row['description']! as String,
    status: CareStatus.fromStorage(row['status'] as String?),
    createdAt: DateTime.parse(row['created_at']! as String),
    requesterName: (row['requester_name'] as String?) ?? '',
    offerCount: (row['offer_count'] as int?) ?? 0,
    currentUserHasOffered: ((row['has_offered'] as int?) ?? 0) == 1,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'requester_id': requesterId,
    'pet_type': petType,
    'start_date': startDate,
    'end_date': endDate,
    'description': description,
    'status': status.storageValue,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'PetcareRequest(#$id, $petType, ${status.storageValue})';
}
