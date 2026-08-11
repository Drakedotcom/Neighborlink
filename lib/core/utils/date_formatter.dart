import 'package:intl/intl.dart';

///formats dates and timestamps
///in db stored as yyyy-MM-dd
///LuS
class DateFormatter {
  const DateFormatter._();

  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _germanDate = DateFormat('dd.MM.yyyy');
  static final DateFormat _germanDateShort = DateFormat('dd.MM.');
  static final DateFormat _germanDateTime = DateFormat('dd.MM.yyyy, HH:mm');
  static final DateFormat _weekday = DateFormat('EEEE', 'de');


  static String toIsoDate(DateTime date) => _isoDate.format(date);

  static String prettyDate(String isoDate) {
    final parsed = tryParseIsoDate(isoDate);
    return parsed == null ? isoDate : _germanDate.format(parsed);
  }

  static String prettyDateShort(String isoDate) {
    final parsed = tryParseIsoDate(isoDate);
    return parsed == null ? isoDate : _germanDateShort.format(parsed);
  }

  static String prettyTimestamp(DateTime timestamp) =>
      _germanDateTime.format(timestamp);

  static String weekdayName(String isoDate) {
    final parsed = tryParseIsoDate(isoDate);
    if (parsed == null) return '';
    try {
      return _weekday.format(parsed);
    } on Object {
      return '';
    }
  }

  static DateTime? tryParseIsoDate(String value) {
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  ///relative timestamp
  static String relative(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) return 'gerade eben';
    if (difference.inMinutes < 60) return 'vor ${difference.inMinutes} Min.';
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? 'vor 1 Stunde' : 'vor $hours Stunden';
    }
    if (difference.inDays == 1) return 'gestern';
    if (difference.inDays < 7) return 'vor ${difference.inDays} Tagen';
    return _germanDate.format(timestamp);
  }

  ///negative values in past
  static int? daysFromToday(String isoDate) {
    final parsed = tryParseIsoDate(isoDate);
    if (parsed == null) return null;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return parsed.difference(startOfToday).inDays;
  }

  static String expiryHint(String isoDate) {
    final days = daysFromToday(isoDate);
    if (days == null) return 'Haltbar bis $isoDate';
    if (days < 0) return 'abgelaufen';
    if (days == 0) return 'läuft heute ab';
    if (days == 1) return 'läuft morgen ab';
    return 'haltbar bis ${prettyDate(isoDate)}';
  }
}