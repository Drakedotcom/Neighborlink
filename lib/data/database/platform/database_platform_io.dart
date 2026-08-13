import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

///LuS
///platform for logging
String get platformLabel {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'macOS';
  return Platform.operatingSystem;
}

///important: desktop needs ffi
bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void configureDatabaseFactory() {
  if (_isDesktop) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
}

///db file
Future<String> resolveDatabasePath(String fileName) async {
  final directory = await sqflite.getDatabasesPath();
  await Directory(directory).create(recursive: true);
  return p.join(directory, fileName);
}

///ffi for testing
void configureTestDatabaseFactory() {
  sqfliteFfiInit();
  sqflite.databaseFactory = databaseFactoryFfi;
}
