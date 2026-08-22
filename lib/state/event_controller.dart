import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/models/neighborhood_event.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_controller.dart' show ViewState;

///NiS
/// State of the events screen.
class EventController extends ChangeNotifier {
  EventController({
    EventRepository repository = const EventRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _repository = repository,
       _notifications = notificationRepository;

  static const String _logTag = 'EventController';

  final EventRepository _repository;
  final NotificationRepository _notifications;

  List<NeighborhoodEvent> _events = const <NeighborhoodEvent>[];
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  List<NeighborhoodEvent> get events => _events;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;

  /// Events in the future, used for the dashboard preview.
  List<NeighborhoodEvent> get upcomingEvents =>
      _events.where((event) => event.isUpcoming).toList();

  Future<void> load({required int neighborhoodId, required int userId}) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  Future<bool> createEvent({
    required AppUser organizer,
    required String title,
    required String location,
    required String eventDate,
    required String eventTime,
    required String description,
    required List<int> neighborIds,
  }) {
    return _runAction(organizer.neighborhoodId, organizer.id, () async {
      await _repository.createEvent(
        neighborhoodId: organizer.neighborhoodId,
        organizerId: organizer.id,
        title: title,
        location: location,
        eventDate: eventDate,
        eventTime: eventTime,
        description: description,
      );

      await _notifications.pushToMany(
        recipientIds: neighborIds,
        title: 'Neues Event: $title',
        message: '${organizer.fullName} lädt am $eventDate nach $location ein.',
        category: NotificationCategory.event,
        triggeredByUserId: organizer.id,
      );

      AppLogger.instance.info(_logTag, 'Event created by #${organizer.id}.');
    });
  }

  Future<bool> joinEvent({
    required NeighborhoodEvent event,
    required AppUser currentUser,
  }) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.join(eventId: event.id, userId: currentUser.id);
      await _notifications.push(
        recipientId: event.organizerId,
        title: 'Neue Zusage',
        message: '${currentUser.fullName} nimmt an "${event.title}" teil.',
        category: NotificationCategory.event,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  Future<bool> leaveEvent({
    required NeighborhoodEvent event,
    required AppUser currentUser,
  }) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.leave(eventId: event.id, userId: currentUser.id);
      await _notifications.push(
        recipientId: event.organizerId,
        title: 'Absage für dein Event',
        message: '${currentUser.fullName} nimmt doch nicht an '
            '"${event.title}" teil.',
        category: NotificationCategory.event,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  Future<bool> deleteEvent({
    required NeighborhoodEvent event,
    required AppUser organizer,
  }) {
    return _runAction(organizer.neighborhoodId, organizer.id, () async {
      final participants = await _repository.participantIds(event.id);
      await _repository.deleteEvent(
        eventId: event.id,
        organizerId: organizer.id,
      );
      await _notifications.pushToMany(
        recipientIds: participants,
        title: 'Event abgesagt',
        message: '"${event.title}" am ${event.eventDate} findet nicht statt.',
        category: NotificationCategory.event,
        triggeredByUserId: organizer.id,
      );
    });
  }

  void reset() {
    _events = const <NeighborhoodEvent>[];
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // --- Internals -------------------------------------------------------------

  Future<bool> _runAction(
    int neighborhoodId,
    int userId,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      await _reload(neighborhoodId: neighborhoodId, userId: userId);
      return true;
    } on AppException catch (error) {
      _errorMessage = error.message;
      _state = ViewState.failure;
      AppLogger.instance.warning(_logTag, 'Event action failed.', error);
      notifyListeners();
      return false;
    }
  }

  Future<void> _reload({
    required int neighborhoodId,
    required int userId,
  }) async {
    try {
      _events = await _repository.loadAll(
        neighborhoodId: neighborhoodId,
        currentUserId: userId,
      );
      _state = ViewState.idle;
      _errorMessage = null;
    } on AppException catch (error) {
      _errorMessage = error.message;
      _state = ViewState.failure;
    }
    notifyListeners();
  }
}
