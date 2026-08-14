import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import 'demo_data_seeder.dart';
import 'platform/database_platform.dart' as platform;
import 'schema/community_schema.dart';
import 'schema/core_schema.dart';
import 'schema/sharing_schema.dart';


///LuS
///single database connection for app
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _logTag = 'AppDatabase';
  static const String _databaseFileName = 'neighborlink.db';
  static const int _schemaVersion = 1;

  sqflite.Database? _database;

  ///must call once from main
  static void registerPlatformFactory() {
    platform.configureDatabaseFactory();
    AppLogger.instance.info(
      _logTag,
      'sqflite factory registered for ${platform.platformLabel}.',
    );
  }

  Future<sqflite.Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    return _database = await _open();
  }

  Future<sqflite.Database> _open() async {
    try {
      final path = await platform.resolveDatabasePath(_databaseFileName);

      AppLogger.instance.info(_logTag, 'Opening database at $path');

      return await sqflite.openDatabase(
        path,
        version: _schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (error) {
      AppLogger.instance.error(_logTag, 'Could not open the database.', error);
      throw DataAccessException(
        'Die Datenbank konnte nicht geöffnet werden.',
        cause: error,
      );
    }
  }

  ///sqlite disables foreign keys by default
  Future<void> _onConfigure(sqflite.Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  ///full schmea by combining sub-schemas
  Future<void> _onCreate(sqflite.Database db, int version) async {
    AppLogger.instance.info(_logTag, 'Creating schema version $version ...');

    final statements = <String>[
      ...CoreSchema.createStatements, 
      ...SharingSchema.createStatements, 
      ...CommunitySchema.createStatements, 
    ];

    await db.transaction((txn) async {
      for (final statement in statements) {
        await txn.execute(statement);
      }
    });

    AppLogger.instance.info(
      _logTag,
      'Schema created (${statements.length} statements).',
    );

    await const DemoDataSeeder().seed(db);
  }

  /// Migration hook. Version 1 is the initial release, so there is nothing to
  /// migrate yet — the method documents the intended upgrade strategy.
  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    AppLogger.instance.warning(
      _logTag,
      'Upgrade requested from v$oldVersion to v$newVersion — '
      'no migration steps are registered yet.',
    );
  }

  /// Deletes the database file. Used by the "Demo zurücksetzen" button so the
  /// presentation can be restarted from a clean state.
  Future<void> resetDatabase() async {
    try {
      final path = await platform.resolveDatabasePath(_databaseFileName);
      await _database?.close();
      _database = null;
      await sqflite.deleteDatabase(path);
      AppLogger.instance.warning(_logTag, 'Database deleted by user request.');
    } catch (error) {
      throw DataAccessException(
        'Die Datenbank konnte nicht zurückgesetzt werden.',
        cause: error,
      );
    }
  }

  /// Closes the connection (called on app shutdown / in tests).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Test seam: lets unit tests inject an in-memory database.
  @visibleForTesting
  Future<void> useInMemoryDatabaseForTests() async {
    platform.configureTestDatabaseFactory();
    await _database?.close();
    _database = await sqflite.databaseFactory.openDatabase(
      sqflite.inMemoryDatabasePath,
      options: sqflite.OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      ),
    );
  }
}
