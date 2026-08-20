import '../../core/errors/app_exception.dart';
import '../database/schema/community_schema.dart';
import '../database/schema/core_schema.dart';
import '../models/neighborhood_event.dart';
import 'base_repository.dart';

///NiS
/// Data access for neighbourhood events.
class EventRepository extends BaseRepository {
  const EventRepository();

  Future<List<NeighborhoodEvent>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
    bool onlyUpcoming = false,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;

      final rows = await database.rawQuery(
        '''
        SELECT e.*,
               organizer.full_name AS organizer_name,
               (SELECT COUNT(*) FROM ${CommunitySchema.tableEventParticipants} p
                 WHERE p.event_id = e.id)                       AS participant_count,
               (SELECT COUNT(*) FROM ${CommunitySchema.tableEventParticipants} p
                 WHERE p.event_id = e.id AND p.user_id = ?)     AS has_joined,
               (SELECT GROUP_CONCAT(u.full_name, '|')
                  FROM ${CommunitySchema.tableEventParticipants} p
                  JOIN ${CoreSchema.tableUsers} u ON u.id = p.user_id
                 WHERE p.event_id = e.id)                       AS participant_names
          FROM ${CommunitySchema.tableEvents} e
          JOIN ${CoreSchema.tableUsers} organizer ON organizer.id = e.organizer_id
         WHERE e.neighborhood_id = ?
           ${onlyUpcoming ? "AND e.event_date >= date('now')" : ''}
      ORDER BY e.event_date ASC, e.event_time ASC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );

      return mapRows(rows, NeighborhoodEvent.fromMap);
    });
  }

  Future<int> createEvent({
    required int neighborhoodId,
    required int organizerId,
    required String title,
    required String location,
    required String eventDate,
    required String eventTime,
    required String description,
  }) {
    return guard('createEvent($title)', () async {
      final database = await db;
      final eventId = await database.insert(
        CommunitySchema.tableEvents,
        <String, Object?>{
          'neighborhood_id': neighborhoodId,
          'organizer_id': organizerId,
          'title': title.trim(),
          'location': location.trim(),
          'event_date': eventDate,
          'event_time': eventTime,
          'description': description.trim(),
          'created_at': nowAsIso,
        },
      );

      // The organiser is automatically the first participant.
      await database.insert(
        CommunitySchema.tableEventParticipants,
        <String, Object?>{
          'event_id': eventId,
          'user_id': organizerId,
          'joined_at': nowAsIso,
        },
      );

      return eventId;
    });
  }

  Future<void> join({required int eventId, required int userId}) {
    return guard('join(event #$eventId)', () async {
      final database = await db;
      final existing = await database.query(
        CommunitySchema.tableEventParticipants,
        where: 'event_id = ? AND user_id = ?',
        whereArgs: <Object?>[eventId, userId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const BusinessRuleException('Du nimmst bereits teil.');
      }

      await database.insert(
        CommunitySchema.tableEventParticipants,
        <String, Object?>{
          'event_id': eventId,
          'user_id': userId,
          'joined_at': nowAsIso,
        },
      );
    });
  }

  Future<void> leave({required int eventId, required int userId}) {
    return guard('leave(event #$eventId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        CommunitySchema.tableEventParticipants,
        where: 'event_id = ? AND user_id = ?',
        whereArgs: <Object?>[eventId, userId],
      );
      if (affectedRows == 0) {
        throw const NotFoundException('Du nimmst an diesem Event nicht teil.');
      }
    });
  }

  Future<List<int>> participantIds(int eventId) {
    return guard('participantIds(#$eventId)', () async {
      final database = await db;
      final rows = await database.query(
        CommunitySchema.tableEventParticipants,
        columns: <String>['user_id'],
        where: 'event_id = ?',
        whereArgs: <Object?>[eventId],
      );
      return rows.map((row) => row['user_id']! as int).toList(growable: false);
    });
  }

  Future<void> deleteEvent({required int eventId, required int organizerId}) {
    return guard('deleteEvent(#$eventId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        CommunitySchema.tableEvents,
        where: 'id = ? AND organizer_id = ?',
        whereArgs: <Object?>[eventId, organizerId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die organisierende Person kann das Event löschen.',
        );
      }
    });
  }

  /// Events that still lie ahead (dashboard figure).
  Future<int> countUpcoming(int neighborhoodId) {
    return guard('countUpcoming($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        "SELECT COUNT(*) AS total FROM ${CommunitySchema.tableEvents} "
        "WHERE neighborhood_id = ? AND event_date >= date('now')",
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}
