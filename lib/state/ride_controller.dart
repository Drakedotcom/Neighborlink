import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/models/ride.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/ride_repository.dart';
import 'auth_controller.dart' show ViewState;

///NiS
/// State of the ride sharing screen.
class RideController extends ChangeNotifier {
  RideController({
    RideRepository repository = const RideRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _repository = repository,
       _notifications = notificationRepository;

  static const String _logTag = 'RideController';

  final RideRepository _repository;
  final NotificationRepository _notifications;

  List<Ride> _rides = const <Ride>[];
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  bool _onlyUpcoming = true;

  List<Ride> get rides => _rides;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  bool get onlyUpcoming => _onlyUpcoming;

  /// Rides that still have a free seat — shown on the dashboard.
  int get ridesWithFreeSeats => _rides.where((ride) => !ride.isFullyBooked).length;

  Future<void> load({required int neighborhoodId, required int userId}) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  /// Switches between "nur kommende Fahrten" and the full history.
  Future<void> toggleUpcomingFilter({
    required int neighborhoodId,
    required int userId,
  }) async {
    _onlyUpcoming = !_onlyUpcoming;
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  Future<bool> createRide({
    required AppUser driver,
    required String origin,
    required String destination,
    required String departureDate,
    required String departureTime,
    required int totalSeats,
    required String note,
    required List<int> neighborIds,
  }) {
    return _runAction(driver.neighborhoodId, driver.id, () async {
      await _repository.createRide(
        neighborhoodId: driver.neighborhoodId,
        driverId: driver.id,
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        departureTime: departureTime,
        totalSeats: totalSeats,
        note: note,
      );

      await _notifications.pushToMany(
        recipientIds: neighborIds,
        title: 'Neue Fahrgemeinschaft',
        message: '${driver.fullName} fährt von $origin nach $destination.',
        category: NotificationCategory.ride,
        triggeredByUserId: driver.id,
      );

      AppLogger.instance.info(_logTag, 'Ride created by #${driver.id}.');
    });
  }

  /// Joins a ride and tells the driver about the new passenger.
  Future<bool> joinRide({required Ride ride, required AppUser currentUser}) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.join(rideId: ride.id, userId: currentUser.id);
      await _notifications.push(
        recipientId: ride.driverId,
        title: 'Neue Mitfahrt',
        message: '${currentUser.fullName} fährt am '
            '${ride.departureDate} nach ${ride.destination} mit.',
        category: NotificationCategory.ride,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  /// Withdraws from a ride ("Anfrage zurückziehen").
  Future<bool> leaveRide({required Ride ride, required AppUser currentUser}) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.leave(rideId: ride.id, userId: currentUser.id);
      await _notifications.push(
        recipientId: ride.driverId,
        title: 'Mitfahrt abgesagt',
        message: '${currentUser.fullName} fährt am ${ride.departureDate} '
            'doch nicht mit.',
        category: NotificationCategory.ride,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  /// The driver cancels the ride; every passenger is informed.
  Future<bool> deleteRide({required Ride ride, required AppUser driver}) {
    return _runAction(driver.neighborhoodId, driver.id, () async {
      final passengers = await _repository.participantIds(ride.id);
      await _repository.deleteRide(rideId: ride.id, driverId: driver.id);
      await _notifications.pushToMany(
        recipientIds: passengers,
        title: 'Fahrt abgesagt',
        message: 'Die Fahrt nach ${ride.destination} am '
            '${ride.departureDate} wurde abgesagt.',
        category: NotificationCategory.ride,
        triggeredByUserId: driver.id,
      );
    });
  }

  void reset() {
    _rides = const <Ride>[];
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
      AppLogger.instance.warning(_logTag, 'Ride action failed.', error);
      notifyListeners();
      return false;
    }
  }

  Future<void> _reload({
    required int neighborhoodId,
    required int userId,
  }) async {
    try {
      _rides = await _repository.loadAll(
        neighborhoodId: neighborhoodId,
        currentUserId: userId,
        onlyUpcoming: _onlyUpcoming,
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
