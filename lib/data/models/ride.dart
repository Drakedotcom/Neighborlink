import 'package:flutter/foundation.dart';

///NiS
/// A car-pooling offer created by a neighbour.
///
/// Free seats are **not** stored in the table. They are derived from
/// `total_seats - takenSeats`, where `takenSeats` comes from a COUNT over the
/// `ride_participants` join table. That guarantees the number can never drift
/// out of sync with the actual list of passengers.
@immutable
class Ride {
  const Ride({
    required this.id,
    required this.neighborhoodId,
    required this.driverId,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.departureTime,
    required this.totalSeats,
    required this.note,
    required this.createdAt,
    this.driverName = '',
    this.takenSeats = 0,
    this.currentUserHasJoined = false,
    this.participantNames = const <String>[],
  });

  final int id;
  final int neighborhoodId;
  final int driverId;
  final String origin;
  final String destination;

  /// ISO date (`yyyy-MM-dd`) so string sorting equals chronological sorting.
  final String departureDate;

  /// 24 hour time (`HH:mm`).
  final String departureTime;

  final int totalSeats;
  final String note;
  final DateTime createdAt;

  // --- Derived fields --------------------------------------------------------
  final String driverName;
  final int takenSeats;
  final bool currentUserHasJoined;
  final List<String> participantNames;

  /// Seats that are still bookable — never negative.
  int get freeSeats => (totalSeats - takenSeats).clamp(0, totalSeats);

  bool get isFullyBooked => freeSeats == 0;

  bool isDrivenBy(int userId) => driverId == userId;

  factory Ride.fromMap(Map<String, Object?> row) => Ride(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    driverId: row['driver_id']! as int,
    origin: row['origin']! as String,
    destination: row['destination']! as String,
    departureDate: row['departure_date']! as String,
    departureTime: row['departure_time']! as String,
    totalSeats: row['total_seats']! as int,
    note: (row['note'] as String?) ?? '',
    createdAt: DateTime.parse(row['created_at']! as String),
    driverName: (row['driver_name'] as String?) ?? '',
    takenSeats: (row['taken_seats'] as int?) ?? 0,
    currentUserHasJoined: ((row['has_joined'] as int?) ?? 0) == 1,
    participantNames: _splitNames(row['participant_names'] as String?),
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'driver_id': driverId,
    'origin': origin,
    'destination': destination,
    'departure_date': departureDate,
    'departure_time': departureTime,
    'total_seats': totalSeats,
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  /// SQLite's GROUP_CONCAT returns a single comma separated string.
  static List<String> _splitNames(String? concatenated) {
    if (concatenated == null || concatenated.isEmpty) return const <String>[];
    return concatenated.split('|').where((name) => name.isNotEmpty).toList();
  }

  @override
  String toString() =>
      'Ride(#$id, $origin -> $destination, $freeSeats/$totalSeats free)';
}
