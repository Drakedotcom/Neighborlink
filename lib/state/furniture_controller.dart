import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/models/furniture_offer.dart';
import '../data/repositories/furniture_repository.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_controller.dart' show ViewState;

/// State of the furniture giveaway screen.
class FurnitureController extends ChangeNotifier {
  FurnitureController({
    FurnitureRepository repository = const FurnitureRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _repository = repository,
       _notifications = notificationRepository;

  static const String _logTag = 'FurnitureController';

  final FurnitureRepository _repository;
  final NotificationRepository _notifications;

  List<FurnitureOffer> _offers = const <FurnitureOffer>[];
  final Map<int, List<FurnitureRequest>> _requestsByOffer =
      <int, List<FurnitureRequest>>{};
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  List<FurnitureOffer> get offers => _offers;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  int get availableCount => _offers.where((offer) => offer.isAvailable).length;

  /// Cached requests of an offer (loaded on demand when the owner expands it).
  List<FurnitureRequest> requestsFor(int offerId) =>
      _requestsByOffer[offerId] ?? const <FurnitureRequest>[];

  Future<void> load({required int neighborhoodId, required int userId}) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  /// Loads the request list of one offer so the owner can decide.
  Future<void> loadRequests(int offerId) async {
    try {
      _requestsByOffer[offerId] = await _repository.loadRequests(offerId);
      notifyListeners();
    } on AppException catch (error) {
      _fail(error);
    }
  }

  Future<bool> createOffer({
    required AppUser owner,
    required String title,
    required String description,
    required String conditionLabel,
  }) {
    return _runAction(owner.neighborhoodId, owner.id, () async {
      await _repository.createOffer(
        neighborhoodId: owner.neighborhoodId,
        ownerId: owner.id,
        title: title,
        description: description,
        conditionLabel: conditionLabel,
      );
      AppLogger.instance.info(_logTag, 'Furniture offer created.');
    });
  }

  /// A neighbour asks for the item; the owner is notified immediately.
  Future<bool> sendRequest({
    required FurnitureOffer offer,
    required AppUser currentUser,
    required String message,
  }) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.sendRequest(
        offerId: offer.id,
        requesterId: currentUser.id,
        message: message,
      );
      await _notifications.push(
        recipientId: offer.ownerId,
        title: 'Neue Anfrage',
        message: '${currentUser.fullName} interessiert sich für '
            '"${offer.title}".',
        category: NotificationCategory.request,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  Future<bool> withdrawRequest({
    required FurnitureOffer offer,
    required AppUser currentUser,
  }) {
    return _runAction(currentUser.neighborhoodId, currentUser.id, () async {
      await _repository.withdrawRequest(
        offerId: offer.id,
        requesterId: currentUser.id,
      );
      await _notifications.push(
        recipientId: offer.ownerId,
        title: 'Anfrage zurückgezogen',
        message: '${currentUser.fullName} hat die Anfrage für '
            '"${offer.title}" zurückgezogen.',
        category: NotificationCategory.request,
        triggeredByUserId: currentUser.id,
      );
    });
  }

  /// The owner accepts one of the requests.
  Future<bool> acceptRequest({
    required FurnitureOffer offer,
    required AppUser owner,
    required FurnitureRequest request,
  }) {
    return _runAction(owner.neighborhoodId, owner.id, () async {
      await _repository.acceptRequest(
        offerId: offer.id,
        ownerId: owner.id,
        requesterId: request.requesterId,
      );

      await _notifications.push(
        recipientId: request.requesterId,
        title: 'Anfrage angenommen',
        message: '${owner.fullName} hat dir "${offer.title}" zugesagt. '
            'Meldet euch zur Übergabe!',
        category: NotificationCategory.request,
        triggeredByUserId: owner.id,
      );

      // Everyone else gets a short cancellation note.
      final declined = requestsFor(offer.id)
          .where(
            (other) =>
                other.requesterId != request.requesterId &&
                other.status == FurnitureRequestStatus.pending,
          )
          .map((other) => other.requesterId)
          .toList();
      await _notifications.pushToMany(
        recipientIds: declined,
        title: 'Gegenstand vergeben',
        message: '"${offer.title}" wurde leider an jemand anderen vergeben.',
        category: NotificationCategory.request,
        triggeredByUserId: owner.id,
      );

      await loadRequests(offer.id);
    });
  }

  Future<bool> markAsGivenAway({
    required FurnitureOffer offer,
    required AppUser owner,
  }) {
    return _runAction(owner.neighborhoodId, owner.id, () async {
      await _repository.markAsGivenAway(offerId: offer.id, ownerId: owner.id);
      final holderId = offer.reservedById;
      if (holderId != null) {
        await _notifications.push(
          recipientId: holderId,
          title: 'Übergabe bestätigt',
          message: '${owner.fullName} hat die Übergabe von "${offer.title}" '
              'bestätigt.',
          category: NotificationCategory.request,
          triggeredByUserId: owner.id,
        );
      }
    });
  }

  Future<bool> deleteOffer({
    required FurnitureOffer offer,
    required AppUser owner,
  }) {
    return _runAction(owner.neighborhoodId, owner.id, () async {
      await _repository.deleteOffer(offerId: offer.id, ownerId: owner.id);
      _requestsByOffer.remove(offer.id);
    });
  }

  void reset() {
    _offers = const <FurnitureOffer>[];
    _requestsByOffer.clear();
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

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
      _fail(error);
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

  void _fail(AppException error) {
    _errorMessage = error.message;
    _state = ViewState.failure;
    AppLogger.instance.warning(_logTag, 'Furniture action failed.', error);
    notifyListeners();
  }
}
