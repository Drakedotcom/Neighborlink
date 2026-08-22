import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/models/food_share.dart';
import '../data/repositories/food_share_repository.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_controller.dart' show ViewState;

/// State of the food sharing screen.
class FoodController extends ChangeNotifier {
  FoodController({
    FoodShareRepository repository = const FoodShareRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _repository = repository,
       _notifications = notificationRepository;

  static const String _logTag = 'FoodController';

  final FoodShareRepository _repository;
  final NotificationRepository _notifications;

  List<FoodShare> _offers = const <FoodShare>[];
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  bool _hideClosedOffers = false;

  List<FoodShare> get offers => _hideClosedOffers
      ? _offers.where((offer) => !offer.isClosed).toList()
      : _offers;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  bool get hideClosedOffers => _hideClosedOffers;

  int get availableCount => _offers.where((offer) => offer.isAvailable).length;

  Future<void> load({required int neighborhoodId, required int userId}) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  void toggleClosedVisibility() {
    _hideClosedOffers = !_hideClosedOffers;
    notifyListeners();
  }

  /// Creates a new food offer.
  Future<bool> createOffer({
    required AppUser owner,
    required String title,
    required String description,
    required String quantity,
    required String expiresOn,
  }) async {
    return _runAction(owner.neighborhoodId, owner.id, () async {
      await _repository.createOffer(
        neighborhoodId: owner.neighborhoodId,
        ownerId: owner.id,
        title: title,
        description: description,
        quantity: quantity,
        expiresOn: expiresOn,
      );
      AppLogger.instance.info(_logTag, 'Food offer created by #${owner.id}.');
    });
  }

  /// The owner receives a notification that smo is interested.
  Future<bool> toggleInterest({
    required FoodShare offer,
    required AppUser currentUser,
  }) async {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      final isNowInterested = await _repository.toggleInterest(
        foodShareId: offer.id,
        userId: currentUser.id,
      );
      if (isNowInterested) {
        await _notifications.push(
          recipientId: offer.ownerId,
          title: 'Interesse an deinem Angebot',
          message:
              '${currentUser.fullName} interessiert sich für "${offer.title}".',
          category: NotificationCategory.reservation,
          triggeredByUserId: currentUser.id,
        );
      }
    });
  }

  /// Reserves an offer and informs both the owner and the other interested
  /// neighbours that the item is gone.
  Future<bool> reserve({
    required FoodShare offer,
    required AppUser currentUser,
  }) async {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.reserve(foodShareId: offer.id, userId: currentUser.id);

      await _notifications.push(
        recipientId: offer.ownerId,
        title: 'Angebot reserviert',
        message:
            '${currentUser.fullName} hat "${offer.title}" reserviert und meldet '
            'sich zur Abholung.',
        category: NotificationCategory.reservation,
        triggeredByUserId: currentUser.id,
      );

      final otherInterested = await _repository.interestedUserIds(offer.id);
      await _notifications.pushToMany(
        recipientIds: otherInterested
            .where((id) => id != currentUser.id && id != offer.ownerId)
            .toList(),
        title: 'Angebot bereits vergeben',
        message: '"${offer.title}" wurde inzwischen reserviert.',
        category: NotificationCategory.reservation,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  Future<bool> cancelReservation({
    required FoodShare offer,
    required AppUser currentUser,
  }) async {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.cancelReservation(
        foodShareId: offer.id,
        actingUserId: currentUser.id,
      );
      final recipientId = currentUser.id == offer.ownerId
          ? offer.reservedById
          : offer.ownerId;
      if (recipientId != null) {
        await _notifications.push(
          recipientId: recipientId,
          title: 'Reservierung aufgehoben',
          message: 'Die Reservierung für "${offer.title}" wurde zurückgenommen.',
          category: NotificationCategory.reservation,
          triggeredByUserId: currentUser.id,
        );
      }
    });
  }

  /// The owner confirms that the food was collected.
  Future<bool> markAsPickedUp({
    required FoodShare offer,
    required AppUser currentUser,
  }) async {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.markAsPickedUp(
        foodShareId: offer.id,
        ownerId: currentUser.id,
      );
      final holderId = offer.reservedById;
      if (holderId != null) {
        await _notifications.push(
          recipientId: holderId,
          title: 'Abholung bestätigt',
          message: '${currentUser.fullName} hat die Abholung von '
              '"${offer.title}" bestätigt. Danke fürs Retten!',
          category: NotificationCategory.reservation,
          triggeredByUserId: currentUser.id,
        );
      }
    });
  }

  Future<bool> deleteOffer({
    required FoodShare offer,
    required AppUser currentUser,
  }) async {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.deleteOffer(
        foodShareId: offer.id,
        ownerId: currentUser.id,
      );
    });
  }

  void reset() {
    _offers = const <FoodShare>[];
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Executes [action] and reloads the list afterwards.
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
      AppLogger.instance.warning(_logTag, 'Action failed: ${error.message}');
      notifyListeners();
      return false;
    }
  }

  Future<void> _reload({
    required int neighborhoodId,
    required int userId,
  }) async {
    try {
      _offers = await _repository.loadAll(
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
