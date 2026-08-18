import '../../core/errors/app_exception.dart';
import '../database/schema/core_schema.dart';
import '../models/app_user.dart';
import '../models/neighborhood.dart';
import 'base_repository.dart';

///neighborhodd is created when user
///registers it for the first time
class NeighborhoodRepository extends BaseRepository {
  const NeighborhoodRepository();

  Future<Neighborhood> findOrCreateByPostalCode(
    String postalCode, {
    String cityName = 'Unbekannter Ort',
  }) {
    return guard('findOrCreateByPostalCode($postalCode)', () async {
      final database = await db;

      final existing = await database.query(
        CoreSchema.tableNeighborhoods,
        where: 'postal_code = ?',
        whereArgs: <Object?>[postalCode],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return Neighborhood.fromMap(existing.first);
      }

      final now = DateTime.now();
      final id = await database.insert(CoreSchema.tableNeighborhoods, {
        'postal_code': postalCode,
        'city_name': cityName,
        'description': 'Nachbarschaft $postalCode – gemeinsam, lokal, nachhaltig.',
        'created_at': now.toIso8601String(),
      });

      return Neighborhood(
        id: id,
        postalCode: postalCode,
        cityName: cityName,
        description: 'Nachbarschaft $postalCode – gemeinsam, lokal, nachhaltig.',
        createdAt: now,
      );
    });
  }

  Future<Neighborhood> findById(int neighborhoodId) {
    return guard('findById($neighborhoodId)', () async {
      final database = await db;
      ///w/ member count
      final rows = await database.rawQuery(
        '''
        SELECT n.*,
               (SELECT COUNT(*) FROM ${CoreSchema.tableUsers} u
                 WHERE u.neighborhood_id = n.id) AS member_count
          FROM ${CoreSchema.tableNeighborhoods} n
         WHERE n.id = ?
        ''',
        <Object?>[neighborhoodId],
      );

      if (rows.isEmpty) {
        throw NotFoundException('Die Nachbarschaft wurde nicht gefunden.');
      }
      return Neighborhood.fromMap(rows.first);
    });
  }

  Future<List<AppUser>> loadMembers(int neighborhoodId) {
    return guard('loadMembers($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableUsers,
        where: 'neighborhood_id = ?',
        whereArgs: <Object?>[neighborhoodId],
        orderBy: 'full_name COLLATE NOCASE ASC',
      );
      return mapRows(rows, AppUser.fromMap);
    });
  }

  ///registered members
  Future<int> countMembers(int neighborhoodId) {
    return guard('countMembers($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${CoreSchema.tableUsers} '
        'WHERE neighborhood_id = ?',
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }

  Future<List<Neighborhood>> loadAll() {
    return guard('loadAll()', () async {
      final database = await db;
      final rows = await database.rawQuery('''
        SELECT n.*,
               (SELECT COUNT(*) FROM ${CoreSchema.tableUsers} u
                 WHERE u.neighborhood_id = n.id) AS member_count
          FROM ${CoreSchema.tableNeighborhoods} n
      ORDER BY n.postal_code ASC
      ''');
      return mapRows(rows, Neighborhood.fromMap);
    });
  }
}