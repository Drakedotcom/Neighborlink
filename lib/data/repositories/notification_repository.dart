import 'package:sqflite/sqflite.dart' as sqflite;

import '../database/schema/core_schema.dart';
import '../models/app_notification.dart';
import 'base_repository.dart';

///LuS
class NotificationRepository extends BaseRepository {
  const NotificationRepository();

  Future<void> push({
    required int recipientId,
    required String title,
    required String message,
    required NotificationCategory category,
    int? triggeredByUserId,
  }) {
    return guard('push(to #$recipientId)', () async {
      ///not notify about self
      if (triggeredByUserId != null && triggeredByUserId == recipientId) {
        return;
      }
      final database = await db;
      await database.insert(CoreSchema.tableNotifications, {
        'recipient_id': recipientId,
        'title': title,
        'message': message,
        'category': category.storageValue,
        'is_read': 0,
        'created_at': nowAsIso,
      });
    });
  }

  Future<void> pushToMany({
    required List<int> recipientIds,
    required String title,
    required String message,
    required NotificationCategory category,
    int? triggeredByUserId,
  }) {
    return guard('pushToMany(${recipientIds.length} recipients)', () async {
      final database = await db;
      final timestamp = nowAsIso;
      await database.transaction((txn) async {
        for (final recipientId in recipientIds) {
          if (recipientId == triggeredByUserId) continue;
          await txn.insert(CoreSchema.tableNotifications, {
            'recipient_id': recipientId,
            'title': title,
            'message': message,
            'category': category.storageValue,
            'is_read': 0,
            'created_at': timestamp,
          });
        }
      });
    });
  }

  Future<List<AppNotification>> loadForUser(int userId) {
    return guard('loadForUser(#$userId)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableNotifications,
        where: 'recipient_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'created_at DESC, id DESC',
      );
      return mapRows(rows, AppNotification.fromMap);
    });
  }

  Future<int> countUnread(int userId) {
    return guard('countUnread(#$userId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${CoreSchema.tableNotifications} '
        'WHERE recipient_id = ? AND is_read = 0',
        <Object?>[userId],
      );
      return sqflite.Sqflite.firstIntValue(rows) ?? 0;
    });
  }

  Future<void> markAsRead(int notificationId) {
    return guard('markAsRead(#$notificationId)', () async {
      final database = await db;
      await database.update(
        CoreSchema.tableNotifications,
        <String, Object?>{'is_read': 1},
        where: 'id = ?',
        whereArgs: <Object?>[notificationId],
      );
    });
  }

  Future<void> markAllAsRead(int userId) {
    return guard('markAllAsRead(#$userId)', () async {
      final database = await db;
      await database.update(
        CoreSchema.tableNotifications,
        <String, Object?>{'is_read': 1},
        where: 'recipient_id = ? AND is_read = 0',
        whereArgs: <Object?>[userId],
      );
    });
  }

  Future<void> deleteAllForUser(int userId) {
    return guard('deleteAllForUser(#$userId)', () async {
      final database = await db;
      await database.delete(
        CoreSchema.tableNotifications,
        where: 'recipient_id = ?',
        whereArgs: <Object?>[userId],
      );
    });
  }
}