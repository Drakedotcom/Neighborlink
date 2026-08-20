// -----------------------------------------------------------------------------
//  NeighborLink · Application State
//  Owner    : Lukas Brandt   (Developer A — Core, Data & Identity)
//  Reviewer : Marie Hoffmann
//  File     : lib/state/notification_controller.dart
// -----------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_controller.dart' show ViewState;

/// Holds the internal notification inbox of the signed-in user.
class NotificationController extends ChangeNotifier {
  NotificationController({
    NotificationRepository repository = const NotificationRepository(),
  }) : _repository = repository;

  static const String _logTag = 'NotificationController';

  final NotificationRepository _repository;

  List<AppNotification> _notifications = const <AppNotification>[];
  int _unreadCount = 0;
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;

  /// Only the unread entries — shown as a highlight block on the dashboard.
  List<AppNotification> get unreadNotifications =>
      _notifications.where((notification) => !notification.isRead).toList();

  Future<void> load(int userId) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(userId);
  }

  /// Cheap refresh used by other modules after they created a notification.
  Future<void> refresh(int userId) => _reload(userId);

  Future<void> markAsRead(int notificationId, int userId) async {
    try {
      await _repository.markAsRead(notificationId);
      await _reload(userId);
    } on AppException catch (error) {
      _fail(error);
    }
  }

  Future<void> markAllAsRead(int userId) async {
    try {
      await _repository.markAllAsRead(userId);
      await _reload(userId);
      AppLogger.instance.info(_logTag, 'Inbox marked as read for #$userId.');
    } on AppException catch (error) {
      _fail(error);
    }
  }

  Future<void> clearInbox(int userId) async {
    try {
      await _repository.deleteAllForUser(userId);
      await _reload(userId);
    } on AppException catch (error) {
      _fail(error);
    }
  }

  void reset() {
    _notifications = const <AppNotification>[];
    _unreadCount = 0;
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _reload(int userId) async {
    try {
      _notifications = await _repository.loadForUser(userId);
      _unreadCount = await _repository.countUnread(userId);
      _state = ViewState.idle;
      _errorMessage = null;
    } on AppException catch (error) {
      _fail(error, notify: false);
    }
    notifyListeners();
  }

  void _fail(AppException error, {bool notify = true}) {
    _errorMessage = error.message;
    _state = ViewState.failure;
    AppLogger.instance.warning(_logTag, 'Inbox operation failed.', error);
    if (notify) notifyListeners();
  }
}
