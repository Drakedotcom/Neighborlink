import '../../core/errors/app_exception.dart';
import '../database/schema/community_schema.dart';
import '../database/schema/core_schema.dart';
import '../models/ride.dart';
import 'base_repository.dart';

///NiS
/// Data access for car pooling.
class RideRepository extends BaseRepository {
  const RideRepository();

  /// All rides of a neighbourhood, sorted by departure.
  /// The query derives `taken_seats`, the "did I already join" flag and a
  /// pipe separated list of passenger names in one round trip.
  Future<List<Ride>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
    bool onlyUpcoming = false,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;

      final rows = await database.rawQuery(
        '''
        SELECT r.*,
               driver.full_name AS driver_name,
               (SELECT COUNT(*) FROM ${CommunitySchema.tableRideParticipants} p
                 WHERE p.ride_id = r.id)                        AS taken_seats,
               (SELECT COUNT(*) FROM ${CommunitySchema.tableRideParticipants} p
                 WHERE p.ride_id = r.id AND p.user_id = ?)      AS has_joined,
               (SELECT GROUP_CONCAT(u.full_name, '|')
                  FROM ${CommunitySchema.tableRideParticipants} p
                  JOIN ${CoreSchema.tableUsers} u ON u.id = p.user_id
                 WHERE p.ride_id = r.id)                        AS participant_names
          FROM ${CommunitySchema.tableRides} r
          JOIN ${CoreSchema.tableUsers} driver ON driver.id = r.driver_id
         WHERE r.neighborhood_id = ?
           ${onlyUpcoming ? "AND r.departure_date >= date('now')" : ''}
      ORDER BY r.departure_date ASC, r.departure_time ASC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );

      return mapRows(rows, Ride.fromMap);
    });
  }

  Future<int> createRide({
    required int neighborhoodId,
    required int driverId,
    required String origin,
    required String destination,
    required String departureDate,
    required String departureTime,
    required int totalSeats,
    required String note,
  }) {
    return guard('createRide($origin -> $destination)', () async {
      if (totalSeats <= 0) {
        throw const ValidationException(
          'Es muss mindestens ein Platz angeboten werden.',
        );
      }

      final database = await db;
      return database.insert(CommunitySchema.tableRides, <String, Object?>{
        'neighborhood_id': neighborhoodId,
        'driver_id': driverId,
        'origin': origin.trim(),
        'destination': destination.trim(),
        'departure_date': departureDate,
        'departure_time': departureTime,
        'total_seats': totalSeats,
        'note': note.trim(),
        'created_at': nowAsIso,
      });
    });
  }

  /// Joins a ride.
  ///
  /// The seat check and the INSERT run inside one transaction, so two
  /// neighbours cannot take the same last seat.
  Future<void> join({required int rideId, required int userId}) {
    return guard('join(ride #$rideId, user #$userId)', () async {
      final database = await db;
      await database.transaction((txn) async {
        final rideRows = await txn.query(
          CommunitySchema.tableRides,
          columns: <String>['total_seats', 'driver_id'],
          where: 'id = ?',
          whereArgs: <Object?>[rideId],
          limit: 1,
        );
        if (rideRows.isEmpty) {
          throw const NotFoundException('Die Fahrt existiert nicht mehr.');
        }
        if (rideRows.first['driver_id'] == userId) {
          throw const BusinessRuleException(
            'Als Fahrer:in bist du bereits dabei.',
          );
        }

        final takenRows = await txn.rawQuery(
          'SELECT COUNT(*) AS taken FROM '
          '${CommunitySchema.tableRideParticipants} WHERE ride_id = ?',
          <Object?>[rideId],
        );
        final takenSeats = (takenRows.first['taken'] as int?) ?? 0;
        final totalSeats = rideRows.first['total_seats']! as int;

        if (takenSeats >= totalSeats) {
          throw const BusinessRuleException(
            'Diese Fahrt ist bereits ausgebucht.',
          );
        }

        final alreadyJoined = await txn.query(
          CommunitySchema.tableRideParticipants,
          where: 'ride_id = ? AND user_id = ?',
          whereArgs: <Object?>[rideId, userId],
          limit: 1,
        );
        if (alreadyJoined.isNotEmpty) {
          throw const BusinessRuleException('Du bist dieser Fahrt schon beigetreten.');
        }

        await txn.insert(
          CommunitySchema.tableRideParticipants,
          <String, Object?>{
            'ride_id': rideId,
            'user_id': userId,
            'joined_at': nowAsIso,
          },
        );
      });
    });
  }

  /// Withdraws from a ride; the free seat becomes available again instantly
  /// because it is derived from this table.
  Future<void> leave({required int rideId, required int userId}) {
    return guard('leave(ride #$rideId, user #$userId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        CommunitySchema.tableRideParticipants,
        where: 'ride_id = ? AND user_id = ?',
        whereArgs: <Object?>[rideId, userId],
      );
      if (affectedRows == 0) {
        throw const NotFoundException('Du bist dieser Fahrt nicht beigetreten.');
      }
    });
  }

  /// Ids of all passengers — used to notify them when a ride is cancelled.
  Future<List<int>> participantIds(int rideId) {
    return guard('participantIds(#$rideId)', () async {
      final database = await db;
      final rows = await database.query(
        CommunitySchema.tableRideParticipants,
        columns: <String>['user_id'],
        where: 'ride_id = ?',
        whereArgs: <Object?>[rideId],
      );
      return rows.map((row) => row['user_id']! as int).toList(growable: false);
    });
  }

  Future<void> deleteRide({required int rideId, required int driverId}) {
    return guard('deleteRide(#$rideId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        CommunitySchema.tableRides,
        where: 'id = ? AND driver_id = ?',
        whereArgs: <Object?>[rideId, driverId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die fahrende Person kann die Fahrt löschen.',
        );
      }
    });
  }

  /// Upcoming rides with at least one free seat (dashboard figure).
  Future<int> countUpcomingWithFreeSeats(int neighborhoodId) {
    return guard('countUpcomingWithFreeSeats($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT COUNT(*) AS total
          FROM ${CommunitySchema.tableRides} r
         WHERE r.neighborhood_id = ?
           AND r.departure_date >= date('now')
           AND r.total_seats > (
                 SELECT COUNT(*) FROM ${CommunitySchema.tableRideParticipants} p
                  WHERE p.ride_id = r.id)
        ''',
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}
