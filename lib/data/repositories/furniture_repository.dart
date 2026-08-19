import '../../core/errors/app_exception.dart';
import '../database/schema/core_schema.dart';
import '../database/schema/sharing_schema.dart';
import '../models/furniture_offer.dart';
import 'base_repository.dart';

/// LuL Data access for the gifting furniture module.
class FurnitureRepository extends BaseRepository {
  const FurnitureRepository();

  Future<List<FurnitureOffer>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;

      final rows = await database.rawQuery(
        '''
        SELECT o.*,
               owner.full_name  AS owner_name,
               holder.full_name AS reserved_by_name,
               (SELECT COUNT(*) FROM ${SharingSchema.tableFurnitureRequests} r
                 WHERE r.furniture_offer_id = o.id
                   AND r.status = 'pending')                    AS open_request_count,
               (SELECT COUNT(*) FROM ${SharingSchema.tableFurnitureRequests} r
                 WHERE r.furniture_offer_id = o.id
                   AND r.requester_id = ?)                      AS has_requested
          FROM ${SharingSchema.tableFurnitureOffers} o
          JOIN ${CoreSchema.tableUsers} owner  ON owner.id  = o.owner_id
     LEFT JOIN ${CoreSchema.tableUsers} holder ON holder.id = o.reserved_by_id
         WHERE o.neighborhood_id = ?
      ORDER BY CASE o.status
                 WHEN 'available' THEN 0
                 WHEN 'reserved'  THEN 1
                 ELSE 2
               END,
               o.created_at DESC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );

      return mapRows(rows, FurnitureOffer.fromMap);
    });
  }

  Future<int> createOffer({
    required int neighborhoodId,
    required int ownerId,
    required String title,
    required String description,
    required String conditionLabel,
  }) {
    return guard('createOffer($title)', () async {
      final database = await db;
      return database.insert(
        SharingSchema.tableFurnitureOffers,
        <String, Object?>{
          'neighborhood_id': neighborhoodId,
          'owner_id': ownerId,
          'title': title.trim(),
          'description': description.trim(),
          'condition_label': conditionLabel.trim(),
          'status': FurnitureStatus.available.storageValue,
          'created_at': nowAsIso,
        },
      );
    });
  }

  /// Sends a request for an item.
  Future<void> sendRequest({
    required int offerId,
    required int requesterId,
    required String message,
  }) {
    return guard('sendRequest(offer #$offerId)', () async {
      final database = await db;

      // Guard 1: the offer must still be open.
      final offerRows = await database.query(
        SharingSchema.tableFurnitureOffers,
        columns: <String>['status', 'owner_id'],
        where: 'id = ?',
        whereArgs: <Object?>[offerId],
        limit: 1,
      );
      if (offerRows.isEmpty) {
        throw const NotFoundException('Das Angebot existiert nicht mehr.');
      }
      if (offerRows.first['owner_id'] == requesterId) {
        throw const BusinessRuleException(
          'Für das eigene Angebot kann keine Anfrage gestellt werden.',
        );
      }
      if (offerRows.first['status'] != FurnitureStatus.available.storageValue) {
        throw const BusinessRuleException(
          'Dieser Gegenstand ist bereits vergeben oder reserviert.',
        );
      }

      // Guard 2: only one request per user (enforced by a UNIQUE index too).
      final existing = await database.query(
        SharingSchema.tableFurnitureRequests,
        where: 'furniture_offer_id = ? AND requester_id = ?',
        whereArgs: <Object?>[offerId, requesterId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const BusinessRuleException(
          'Du hast für diesen Gegenstand bereits eine Anfrage gestellt.',
        );
      }

      await database.insert(
        SharingSchema.tableFurnitureRequests,
        <String, Object?>{
          'furniture_offer_id': offerId,
          'requester_id': requesterId,
          'message': message.trim(),
          'status': FurnitureRequestStatus.pending.storageValue,
          'created_at': nowAsIso,
        },
      );
    });
  }

  Future<void> withdrawRequest({
    required int offerId,
    required int requesterId,
  }) {
    return guard('withdrawRequest(offer #$offerId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        SharingSchema.tableFurnitureRequests,
        where: 'furniture_offer_id = ? AND requester_id = ?',
        whereArgs: <Object?>[offerId, requesterId],
      );
      if (affectedRows == 0) {
        throw const NotFoundException('Es gibt keine Anfrage zum Zurückziehen.');
      }
    });
  }

  /// All requests for one offer, used by the owner's detail sheet.
  Future<List<FurnitureRequest>> loadRequests(int offerId) {
    return guard('loadRequests(offer #$offerId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT r.*, u.full_name AS requester_name
          FROM ${SharingSchema.tableFurnitureRequests} r
          JOIN ${CoreSchema.tableUsers} u ON u.id = r.requester_id
         WHERE r.furniture_offer_id = ?
      ORDER BY r.created_at ASC
        ''',
        <Object?>[offerId],
      );
      return mapRows(rows, FurnitureRequest.fromMap);
    });
  }

  /// The owner accepts one request: the item becomes reserved for that
  /// neighbour and all other pending requests are declined.
  Future<void> acceptRequest({
    required int offerId,
    required int ownerId,
    required int requesterId,
  }) {
    return guard('acceptRequest(offer #$offerId)', () async {
      final database = await db;
      await database.transaction((txn) async {
        final updated = await txn.update(
          SharingSchema.tableFurnitureOffers,
          <String, Object?>{
            'status': FurnitureStatus.reserved.storageValue,
            'reserved_by_id': requesterId,
          },
          where: 'id = ? AND owner_id = ? AND status = ?',
          whereArgs: <Object?>[
            offerId,
            ownerId,
            FurnitureStatus.available.storageValue,
          ],
        );
        if (updated == 0) {
          throw const BusinessRuleException(
            'Der Gegenstand ist nicht mehr verfügbar.',
          );
        }

        await txn.update(
          SharingSchema.tableFurnitureRequests,
          <String, Object?>{
            'status': FurnitureRequestStatus.accepted.storageValue,
          },
          where: 'furniture_offer_id = ? AND requester_id = ?',
          whereArgs: <Object?>[offerId, requesterId],
        );
        await txn.update(
          SharingSchema.tableFurnitureRequests,
          <String, Object?>{
            'status': FurnitureRequestStatus.declined.storageValue,
          },
          where: 'furniture_offer_id = ? AND requester_id != ? AND status = ?',
          whereArgs: <Object?>[
            offerId,
            requesterId,
            FurnitureRequestStatus.pending.storageValue,
          ],
        );
      });
    });
  }

  /// Final step where the item has been collected.
  Future<void> markAsGivenAway({required int offerId, required int ownerId}) {
    return guard('markAsGivenAway(#$offerId)', () async {
      final database = await db;
      final affectedRows = await database.update(
        SharingSchema.tableFurnitureOffers,
        <String, Object?>{'status': FurnitureStatus.givenAway.storageValue},
        where: 'id = ? AND owner_id = ? AND status = ?',
        whereArgs: <Object?>[
          offerId,
          ownerId,
          FurnitureStatus.reserved.storageValue,
        ],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur reservierte Gegenstände können als vergeben markiert werden.',
        );
      }
    });
  }

  Future<void> deleteOffer({required int offerId, required int ownerId}) {
    return guard('deleteOffer(#$offerId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        SharingSchema.tableFurnitureOffers,
        where: 'id = ? AND owner_id = ?',
        whereArgs: <Object?>[offerId, ownerId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die anbietende Person kann das Angebot löschen.',
        );
      }
    });
  }

  Future<int> countAvailable(int neighborhoodId) {
    return guard('countAvailable($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        "SELECT COUNT(*) AS total FROM ${SharingSchema.tableFurnitureOffers} "
        "WHERE neighborhood_id = ? AND status = 'available'",
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}
