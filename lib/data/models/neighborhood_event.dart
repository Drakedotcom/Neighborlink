import 'package:flutter/foundation.dart';

import '../../core/utils/date_formatter.dart';

///NiS
/// A neighbourhood event that everybody can join.
@immutable
class NeighborhoodEvent {
  const NeighborhoodEvent({
    required this.id,
    required this.neighborhoodId,
    required this.organizerId,
    required this.title,
    required this.location,
    required this.eventDate,
    required this.eventTime,
    required this.description,
    required this.createdAt,
    this.organizerName = '',
    this.participantCount = 0,
    this.currentUserHasJoined = false,
    this.participantNames = const <String>[],
  });

  final int id;
  final int neighborhoodId;
  final int organizerId;
  final String title;
  final String location;

  /// ISO date (`yyyy-MM-dd`).
  final String eventDate;
  final String eventTime;
  final String description;
  final DateTime createdAt;

  // --- Derived fields --------------------------------------------------------
  final String organizerName;
  final int participantCount;
  final bool currentUserHasJoined;
  final List<String> participantNames;

  /// `true` when the event date is today or in the future.
  bool get isUpcoming => (DateFormatter.daysFromToday(eventDate) ?? -1) >= 0;

  /// Short countdown text, e.g. "in 3 Tagen".
  String get countdownLabel {
    final days = DateFormatter.daysFromToday(eventDate);
    if (days == null) return '';
    if (days < 0) return 'vorbei';
    if (days == 0) return 'heute';
    if (days == 1) return 'morgen';
    return 'in $days Tagen';
  }

  bool isOrganizedBy(int userId) => organizerId == userId;

  factory NeighborhoodEvent.fromMap(Map<String, Object?> row) =>
      NeighborhoodEvent(
        id: row['id']! as int,
        neighborhoodId: row['neighborhood_id']! as int,
        organizerId: row['organizer_id']! as int,
        title: row['title']! as String,
        location: row['location']! as String,
        eventDate: row['event_date']! as String,
        eventTime: (row['event_time'] as String?) ?? '',
        description: row['description']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        organizerName: (row['organizer_name'] as String?) ?? '',
        participantCount: (row['participant_count'] as int?) ?? 0,
        currentUserHasJoined: ((row['has_joined'] as int?) ?? 0) == 1,
        participantNames: _splitNames(row['participant_names'] as String?),
      );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'organizer_id': organizerId,
    'title': title,
    'location': location,
    'event_date': eventDate,
    'event_time': eventTime,
    'description': description,
    'created_at': createdAt.toIso8601String(),
  };

  static List<String> _splitNames(String? concatenated) {
    if (concatenated == null || concatenated.isEmpty) return const <String>[];
    return concatenated.split('|').where((name) => name.isNotEmpty).toList();
  }

  @override
  String toString() =>
      'NeighborhoodEvent(#$id, $title, $participantCount participants)';
}
