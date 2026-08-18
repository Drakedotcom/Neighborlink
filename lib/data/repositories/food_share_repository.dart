import '../../core/errors/app_exception.dart';
import '../database/schema/core_schema.dart';
import '../database/schema/sharing_schema.dart';
import '../models/food_share.dart';
import 'base_repository.dart';

/// Data access for the food sharing module.
///
/// All status transitions are implemented as conditional UPDATE statements.
/// If the row no longer has the expected status (because another neighbour
/// was faster), zero rows are affected and we raise a business rule error.
class FoodShareRepository extends BaseRepository {
  const FoodShareRepository();

  /// Loads all offers of a neighbourhood with owner name, interest count and
  /// a flag telling whether [currentUserId] already showed interest.
  Future<List<FoodShare>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
    bool onlyAvailable = false,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;

      final rows = await database.rawQuery(
        '''
        SELECT f.*,
               owner.full_name    AS owner_name,
               holder.full_name   AS reserved_by_name,
               (SELECT COUNT(*) FROM ${SharingSchema.tableFoodInterests} i
                 WHERE i.food_share_id = f.id)               AS interested_count,
               (SELECT COUNT(*) FROM ${SharingSchema.tableFoodInterests} i
                 WHERE i.food_share_id = f.id AND i.user_id = ?) AS is_interested
          FROM ${SharingSchema.tableFoodShares} f
          JOIN ${CoreSchema.tableUsers} owner  ON owner.id  = f.owner_id
     LEFT JOIN ${CoreSchema.tableUsers} holder ON holder.id = f.reserved_by_id
         WHERE f.neighborhood_id = ?
           ${onlyAvailable ? "AND f.status = 'available'" : ''}
      ORDER BY CASE f.status
                 WHEN 'available' THEN 0
                 WHEN 'reserved'  THEN 1
                 ELSE 2
               END,
               f.expires_on ASC, f.id DESC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );

      return mapRows(rows, FoodShare.fromMap);
    });
  }

  Future<int> createOffer({
    required int neighborhoodId,
    required int ownerId,
    required String title,
    required String description,
    required String quantity,
    required String expiresOn,
  }) {
    return guard('createOffer($title)', () async {
      final database = await db;
      return database.insert(SharingSchema.tableFoodShares, <String, Object?>{
        'neighborhood_id': neighborhoodId,
        'owner_id': ownerId,
        'title': title.trim(),
        'description': description.trim(),
        'quantity': quantity.trim(),
        'expires_on': expiresOn,
        'status': FoodShareStatus.available.storageValue,
        'created_at': nowAsIso,
      });
    });
  }

  /// "Interesse bekunden" — toggles the interest flag of a user.
  /// Returns `true` when interest was added, `false` when it was withdrawn.
  Future<bool> toggleInterest({
    required int foodShareId,
    required int userId,
  }) {
    return guard('toggleInterest(#$foodShareId, user #$userId)', () async {
      final database = await db;

      final existing = await database.query(
        SharingSchema.tableFoodInterests,
        where: 'food_share_id = ? AND user_id = ?',
        whereArgs: <Object?>[foodShareId, userId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await database.delete(
          SharingSchema.tableFoodInterests,
          where: 'food_share_id = ? AND user_id = ?',
          whereArgs: <Object?>[foodShareId, userId],
        );
        return false;
      }

      await database.insert(SharingSchema.tableFoodInterests, <String, Object?>{
        'food_share_id': foodShareId,
        'user_id': userId,
        'created_at': nowAsIso,
      });
      return true;
    });
  }

  /// Reserves an offer for [userId]. Only works while it is still available.
  Future<void> reserve({required int foodShareId, required int userId}) {
    return guard('reserve(#$foodShareId)', () async {
      final database = await db;
      final affectedRows = await database.update(
        SharingSchema.tableFoodShares,
        <String, Object?>{
          'status': FoodShareStatus.reserved.storageValue,
          'reserved_by_id': userId,
        },
        where: 'id = ? AND status = ?',
        whereArgs: <Object?>[foodShareId, FoodShareStatus.available.storageValue],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Dieses Angebot ist leider nicht mehr verfügbar.',
        );
      }
    });
  }

  /// Withdraws a reservation. Both the owner and the holder may do this.
  Future<void> cancelReservation({
    required int foodShareId,
    required int actingUserId,
  }) {
    return guard('cancelReservation(#$foodShareId)', () async {
      final database = await db;
      final affectedRows = await database.rawUpdate(
        '''
        UPDATE ${SharingSchema.tableFoodShares}
           SET status = ?, reserved_by_id = NULL
         WHERE id = ?
           AND status = ?
           AND (reserved_by_id = ? OR owner_id = ?)
        ''',
        <Object?>[
          FoodShareStatus.available.storageValue,
          foodShareId,
          FoodShareStatus.reserved.storageValue,
          actingUserId,
          actingUserId,
        ],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Die Reservierung konnte nicht zurückgenommen werden.',
        );
      }
    });
  }

  /// Marks a reserved offer as picked up. Only the owner may confirm this.
  Future<void> markAsPickedUp({
    required int foodShareId,
    required int ownerId,
  }) {
    return guard('markAsPickedUp(#$foodShareId)', () async {
      final database = await db;
      final affectedRows = await database.update(
        SharingSchema.tableFoodShares,
        <String, Object?>{'status': FoodShareStatus.pickedUp.storageValue},
        where: 'id = ? AND owner_id = ? AND status = ?',
        whereArgs: <Object?>[
          foodShareId,
          ownerId,
          FoodShareStatus.reserved.storageValue,
        ],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur reservierte Angebote können als abgeholt markiert werden.',
        );
      }
    });
  }

  Future<void> deleteOffer({required int foodShareId, required int ownerId}) {
    return guard('deleteOffer(#$foodShareId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        SharingSchema.tableFoodShares,
        where: 'id = ? AND owner_id = ?',
        whereArgs: <Object?>[foodShareId, ownerId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die anbietende Person kann das Angebot löschen.',
        );
      }
    });
  }

  /// Ids of everyone who flagged interest — used to notify them when the
  /// item gets reserved by somebody else.
  Future<List<int>> interestedUserIds(int foodShareId) {
    return guard('interestedUserIds(#$foodShareId)', () async {
      final database = await db;
      final rows = await database.query(
        SharingSchema.tableFoodInterests,
        columns: <String>['user_id'],
        where: 'food_share_id = ?',
        whereArgs: <Object?>[foodShareId],
      );
      return rows.map((row) => row['user_id']! as int).toList(growable: false);
    });
  }

  /// Number of offers that are still available (dashboard figure).
  Future<int> countAvailable(int neighborhoodId) {
    return guard('countAvailable($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        "SELECT COUNT(*) AS total FROM ${SharingSchema.tableFoodShares} "
        "WHERE neighborhood_id = ? AND status = 'available'",
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}
