import 'package:sqflite/sqflite.dart' as sqflite;

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../database/app_database.dart';

///LuS
///base repository class
abstract class BaseRepository {
  const BaseRepository();
  String get logTag => runtimeType.toString();
  Future<sqflite.Database> get db async => AppDatabase.instance.database;

  ///domain exceptions
  Future<T> guard<T>(String description, Future<T> Function() action) async {
    try {
      AppLogger.instance.debug(logTag, description);
      return await action();
    } on AppException {
      ///already a domain exception
      rethrow;
    } on sqflite.DatabaseException catch (error) {
      AppLogger.instance.error(logTag, 'SQL error while: $description', error);
      throw DataAccessException(_translateSqlError(error), cause: error);
    } catch (error) {
      AppLogger.instance.error(logTag, 'Unexpected error while: $description', error);
      throw DataAccessException(
        'Es ist ein unerwarteter Fehler aufgetreten.',
        cause: error,
      );
    }
  }

  String _translateSqlError(sqflite.DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return 'Dieser Eintrag existiert bereits.';
    }
    if (error.isNotNullConstraintError()) {
      return 'Es fehlen Pflichtangaben.';
    }
    return 'Die Aktion verletzt eine Datenbankregel und wurde abgebrochen.';
  }

  List<T> mapRows<T>(
    List<Map<String, Object?>> rows,
    T Function(Map<String, Object?> row) mapper,
  ) {
    return rows.map(mapper).toList(growable: false);
  }
  ///table standaard
  String get nowAsIso => DateTime.now().toIso8601String();
}