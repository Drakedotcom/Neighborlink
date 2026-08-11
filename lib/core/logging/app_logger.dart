import 'package:flutter/foundation.dart';

///severity of log entry
enum LogLevel { debug, info, warning, error }

///single log record LuS
@immutable
class LogRecord {
  const LogRecord({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
    this.error,
  });

  final LogLevel level;
  final String tag;
  final String message;
  final DateTime timestamp;
  final Object? error;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] ')
      ..write('${level.name.toUpperCase().padRight(7)} ')
      ..write('$tag: $message');
    if (error != null) buffer.write(' | cause: $error');
    return buffer.toString();
  }
}

/// logging facade LuS. Records printed to debugger and stored for profile display
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();
  /// 300 is more than enough for the project
  static const int _maxBufferSize = 300;
  final List<LogRecord> _buffer = <LogRecord>[];

  List<LogRecord> get records => List.unmodifiable(_buffer);
  LogLevel minimumLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  void debug(String tag, String message) => _write(LogLevel.debug, tag, message);
  void info(String tag, String message) =>  _write(LogLevel.info, tag, message);

  void warning(String tag, String message, [Object? error]) =>
      _write(LogLevel.warning, tag, message, error);
  void error(String tag, String message, [Object? error]) =>
      _write(LogLevel.error, tag, message, error);

  void clear() => _buffer.clear();

  void _write(LogLevel level, String tag, String message, [Object? error]) {
    if (level.index < minimumLevel.index) return;

    final record = LogRecord(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
      error: error,
    );

    _buffer.add(record);
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - _maxBufferSize);
    }
    debugPrint(record.toString());
  }
}