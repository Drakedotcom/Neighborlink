import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/neighbor_link_app.dart';
import 'core/logging/app_logger.dart';
import 'data/database/app_database.dart';

///LuS
Future<void> main() async {
  ///required before plugins
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.instance.info('main', 'Starting NeighborLink ...');

  ///sqflite implementation
  AppDatabase.registerPlatformFactory();
  ///german data
  await initializeDateFormatting('de');

  ///open db in main so app doesnt
  ///deal with half-initialised data
  try {
    await AppDatabase.instance.database;
    AppLogger.instance.info('main', 'Database ready.');
  } catch (error) {
    ///no crash, repos give errors
    AppLogger.instance.error('main', 'Database initialisation failed.', error);
  }

  runApp(const NeighborLinkApp());
}