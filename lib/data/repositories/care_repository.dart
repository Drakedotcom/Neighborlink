import '../../core/errors/app_exception.dart';
import '../database/schema/sharing_schema.dart';
import '../database/schema/core_schema.dart';
import '../models/care_request.dart';
import 'base_repository.dart';

/// Shared behaviour of the care modules.
abstract class CareRepositoryBase extends BaseRepository {
  const CareRepositoryBase();

  /// Table holding the requests.
  String get requestTable;

  /// Table holding the help offers.
  String get offerTable;

  /// Registers help for a request.
  Future<void> offerHelp({
    required int requestId,
    required int helperId,
    required String message,
  }) {
    return guard('offerHelp(request #$requestId)', () async {
      final database = await db;

      final requestRows = await database.query(
        requestTable,
        columns: <String>['requester_id', 'status'],
        where: 'id = ?',
        whereArgs: <Object?>[requestId],
        limit: 1,
      );
      if (requestRows.isEmpty) {
        throw const NotFoundException('Die Anfrage existiert nicht mehr.');
      }
      if (requestRows.first['requester_id'] == helperId) {
        throw const BusinessRuleException(
          'Für die eigene Anfrage kann keine Hilfe angeboten werden.',
        );
      }
      if (requestRows.first['status'] == CareStatus.covered.storageValue) {
        throw const BusinessRuleException(
          'Diese Anfrage ist bereits abgedeckt.',
        );
      }

      final existing = await database.query(
        offerTable,
        where: 'request_id = ? AND helper_id = ?',
        whereArgs: <Object?>[requestId, helperId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const BusinessRuleException('Du hast bereits Hilfe angeboten.');
      }

      await database.insert(offerTable, <String, Object?>{
        'request_id': requestId,
        'helper_id': helperId,
        'message': message.trim(),
        'created_at': nowAsIso,
      });
    });
  }

  Future<void> withdrawHelp({required int requestId, required int helperId}) {
    return guard('withdrawHelp(request #$requestId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        offerTable,
        where: 'request_id = ? AND helper_id = ?',
        whereArgs: <Object?>[requestId, helperId],
      );
      if (affectedRows == 0) {
        throw const NotFoundException('Es gibt kein Angebot zum Zurückziehen.');
      }
    });
  }

  /// All offers for one request, including the helper's name.
  Future<List<CareOffer>> loadOffers(int requestId) {
    return guard('loadOffers(request #$requestId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT o.*, u.full_name AS helper_name
          FROM $offerTable o
          JOIN ${CoreSchema.tableUsers} u ON u.id = o.helper_id
         WHERE o.request_id = ?
      ORDER BY o.created_at ASC
        ''',
        <Object?>[requestId],
      );
      return mapRows(rows, CareOffer.fromMap);
    });
  }

  /// Request is marked as solved.
  Future<void> markAsCovered({
    required int requestId,
    required int requesterId,
  }) {
    return guard('markAsCovered(#$requestId)', () async {
      final database = await db;
      final affectedRows = await database.update(
        requestTable,
        <String, Object?>{'status': CareStatus.covered.storageValue},
        where: 'id = ? AND requester_id = ? AND status = ?',
        whereArgs: <Object?>[
          requestId,
          requesterId,
          CareStatus.open.storageValue,
        ],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur offene, eigene Anfragen können geschlossen werden.',
        );
      }
    });
  }

  Future<void> reopen({required int requestId, required int requesterId}) {
    return guard('reopen(#$requestId)', () async {
      final database = await db;
      await database.update(
        requestTable,
        <String, Object?>{'status': CareStatus.open.storageValue},
        where: 'id = ? AND requester_id = ?',
        whereArgs: <Object?>[requestId, requesterId],
      );
    });
  }

  Future<void> deleteRequest({
    required int requestId,
    required int requesterId,
  }) {
    return guard('deleteRequest(#$requestId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        requestTable,
        where: 'id = ? AND requester_id = ?',
        whereArgs: <Object?>[requestId, requesterId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die anfragende Person kann die Anfrage löschen.',
        );
      }
    });
  }

  /// Number of open requests (dashboard figure).
  Future<int> countOpen(int neighborhoodId) {
    return guard('countOpen($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        "SELECT COUNT(*) AS total FROM $requestTable "
        "WHERE neighborhood_id = ? AND status = 'open'",
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}

/// Data access for child care repo.
class ChildcareRepository extends CareRepositoryBase {
  const ChildcareRepository();

  @override
  String get requestTable => SharingSchema.tableChildcareRequests;

  @override
  String get offerTable => SharingSchema.tableChildcareOffers;

  Future<List<ChildcareRequest>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT c.*,
               u.full_name AS requester_name,
               (SELECT COUNT(*) FROM $offerTable o
                 WHERE o.request_id = c.id)                     AS offer_count,
               (SELECT COUNT(*) FROM $offerTable o
                 WHERE o.request_id = c.id AND o.helper_id = ?) AS has_offered
          FROM $requestTable c
          JOIN ${CoreSchema.tableUsers} u ON u.id = c.requester_id
         WHERE c.neighborhood_id = ?
      ORDER BY CASE c.status WHEN 'open' THEN 0 ELSE 1 END,
               c.care_date ASC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );
      return mapRows(rows, ChildcareRequest.fromMap);
    });
  }

  Future<int> createRequest({
    required int neighborhoodId,
    required int requesterId,
    required String careDate,
    required String careTime,
    required String description,
  }) {
    return guard('createRequest($careDate)', () async {
      final database = await db;
      return database.insert(requestTable, <String, Object?>{
        'neighborhood_id': neighborhoodId,
        'requester_id': requesterId,
        'care_date': careDate,
        'care_time': careTime.trim(),
        'description': description.trim(),
        'status': CareStatus.open.storageValue,
        'created_at': nowAsIso,
      });
    });
  }
}

/// Data access for pet care repo".
class PetcareRepository extends CareRepositoryBase {
  const PetcareRepository();

  @override
  String get requestTable => SharingSchema.tablePetcareRequests;

  @override
  String get offerTable => SharingSchema.tablePetcareOffers;

  Future<List<PetcareRequest>> loadAll({
    required int neighborhoodId,
    required int currentUserId,
  }) {
    return guard('loadAll(neighborhood=$neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT p.*,
               u.full_name AS requester_name,
               (SELECT COUNT(*) FROM $offerTable o
                 WHERE o.request_id = p.id)                     AS offer_count,
               (SELECT COUNT(*) FROM $offerTable o
                 WHERE o.request_id = p.id AND o.helper_id = ?) AS has_offered
          FROM $requestTable p
          JOIN ${CoreSchema.tableUsers} u ON u.id = p.requester_id
         WHERE p.neighborhood_id = ?
      ORDER BY CASE p.status WHEN 'open' THEN 0 ELSE 1 END,
               p.start_date ASC
        ''',
        <Object?>[currentUserId, neighborhoodId],
      );
      return mapRows(rows, PetcareRequest.fromMap);
    });
  }

  Future<int> createRequest({
    required int neighborhoodId,
    required int requesterId,
    required String petType,
    required String startDate,
    required String endDate,
    required String description,
  }) {
    return guard('createRequest($petType)', () async {
      if (endDate.compareTo(startDate) < 0) {
        throw const ValidationException(
          'Das Enddatum darf nicht vor dem Startdatum liegen.',
        );
      }
      final database = await db;
      return database.insert(requestTable, <String, Object?>{
        'neighborhood_id': neighborhoodId,
        'requester_id': requesterId,
        'pet_type': petType.trim(),
        'start_date': startDate,
        'end_date': endDate,
        'description': description.trim(),
        'status': CareStatus.open.storageValue,
        'created_at': nowAsIso,
      });
    });
  }
}
