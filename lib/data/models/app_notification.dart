import 'package:flutter/foundation.dart';

/// LuS
enum NotificationCategory {
  request('request', 'Anfrage'),
  reservation('reservation', 'Reservierung'),
  event('event', 'Event'),
  ride('ride', 'Fahrgemeinschaft'),
  care('care', 'Betreuung'),
  system('system', 'System');

  const NotificationCategory(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static NotificationCategory fromStorage(String? value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.storageValue == value,
      orElse: () => NotificationCategory.system,
    );
  }
}

///LuS
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.message,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int recipientId;
  final String title;
  final String message;
  final NotificationCategory category;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, Object?> row) {
    return AppNotification(
      id: row['id']! as int,
      recipientId: row['recipient_id']! as int,
      title: row['title']! as String,
      message: row['message']! as String,
      category: NotificationCategory.fromStorage(row['category'] as String?),
      ///sqlite has no boolean type
      isRead: (row['is_read'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'recipient_id': recipientId,
    'title': title,
    'message': message,
    'category': category.storageValue,
    'is_read': isRead ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'AppNotification(#$id, $title, read=$isRead)';
}