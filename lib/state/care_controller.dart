import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/models/care_request.dart';
import '../data/repositories/care_repository.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_controller.dart' show ViewState;

/// LuL State of the child care and pet care screens.
class CareController extends ChangeNotifier {
  CareController({
    ChildcareRepository childcareRepository = const ChildcareRepository(),
    PetcareRepository petcareRepository = const PetcareRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _childcare = childcareRepository,
       _petcare = petcareRepository,
       _notifications = notificationRepository;

  static const String _logTag = 'CareController';

  final ChildcareRepository _childcare;
  final PetcareRepository _petcare;
  final NotificationRepository _notifications;

  List<ChildcareRequest> _childcareRequests = const <ChildcareRequest>[];
  List<PetcareRequest> _petcareRequests = const <PetcareRequest>[];
  final Map<String, List<CareOffer>> _offerCache = <String, List<CareOffer>>{};
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  List<ChildcareRequest> get childcareRequests => _childcareRequests;
  List<PetcareRequest> get petcareRequests => _petcareRequests;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;

  int get openChildcareCount =>
      _childcareRequests.where((request) => request.isOpen).length;
  int get openPetcareCount =>
      _petcareRequests.where((request) => request.isOpen).length;

  /// Offers of a request. [isChildcare] selects the module.
  List<CareOffer> offersFor(int requestId, {required bool isChildcare}) =>
      _offerCache[_cacheKey(requestId, isChildcare)] ?? const <CareOffer>[];

  Future<void> load({required int neighborhoodId, required int userId}) async {
    _state = ViewState.busy;
    notifyListeners();
    await _reload(neighborhoodId: neighborhoodId, userId: userId);
  }

  Future<void> loadOffers(int requestId, {required bool isChildcare}) async {
    try {
      final repository = isChildcare
          ? _childcare as CareRepositoryBase
          : _petcare as CareRepositoryBase;
      _offerCache[_cacheKey(requestId, isChildcare)] = await repository
          .loadOffers(requestId);
      notifyListeners();
    } on AppException catch (error) {
      _fail(error);
    }
  }

  Future<bool> createChildcareRequest({
    required AppUser requester,
    required String careDate,
    required String careTime,
    required String description,
    required List<int> neighborIds,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _childcare.createRequest(
        neighborhoodId: requester.neighborhoodId,
        requesterId: requester.id,
        careDate: careDate,
        careTime: careTime,
        description: description,
      );
      await _notifications.pushToMany(
        recipientIds: neighborIds,
        title: 'Kinderbetreuung gesucht',
        message: '${requester.fullName} sucht am $careDate Unterstützung.',
        category: NotificationCategory.care,
        triggeredByUserId: requester.id,
      );
      AppLogger.instance.info(_logTag, 'Childcare request created.');
    });
  }

  Future<bool> offerChildcareHelp({
    required ChildcareRequest request,
    required AppUser helper,
    required String message,
  }) {
    return _runAction(helper.neighborhoodId, helper.id, () async {
      await _childcare.offerHelp(
        requestId: request.id,
        helperId: helper.id,
        message: message,
      );
      await _notifications.push(
        recipientId: request.requesterId,
        title: 'Hilfe bei der Kinderbetreuung',
        message: '${helper.fullName} bietet Unterstützung für den '
            '${request.careDate} an.',
        category: NotificationCategory.care,
        triggeredByUserId: helper.id,
      );
      await loadOffers(request.id, isChildcare: true);
    });
  }

  Future<bool> withdrawChildcareHelp({
    required ChildcareRequest request,
    required AppUser helper,
  }) {
    return _runAction(helper.neighborhoodId, helper.id, () async {
      await _childcare.withdrawHelp(
        requestId: request.id,
        helperId: helper.id,
      );
      await loadOffers(request.id, isChildcare: true);
    });
  }

  Future<bool> closeChildcareRequest({
    required ChildcareRequest request,
    required AppUser requester,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _childcare.markAsCovered(
        requestId: request.id,
        requesterId: requester.id,
      );
      final helpers = offersFor(request.id, isChildcare: true)
          .map((offer) => offer.helperId)
          .toList();
      await _notifications.pushToMany(
        recipientIds: helpers,
        title: 'Betreuung geklärt',
        message: '${requester.fullName} hat die Betreuung am '
            '${request.careDate} geklärt. Danke für dein Angebot!',
        category: NotificationCategory.care,
        triggeredByUserId: requester.id,
      );
    });
  }

  Future<bool> deleteChildcareRequest({
    required ChildcareRequest request,
    required AppUser requester,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _childcare.deleteRequest(
        requestId: request.id,
        requesterId: requester.id,
      );
      _offerCache.remove(_cacheKey(request.id, true));
    });
  }

  Future<bool> createPetcareRequest({
    required AppUser requester,
    required String petType,
    required String startDate,
    required String endDate,
    required String description,
    required List<int> neighborIds,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _petcare.createRequest(
        neighborhoodId: requester.neighborhoodId,
        requesterId: requester.id,
        petType: petType,
        startDate: startDate,
        endDate: endDate,
        description: description,
      );
      await _notifications.pushToMany(
        recipientIds: neighborIds,
        title: 'Tierbetreuung gesucht',
        message: '${requester.fullName} sucht Betreuung für: $petType.',
        category: NotificationCategory.care,
        triggeredByUserId: requester.id,
      );
    });
  }

  Future<bool> offerPetcareHelp({
    required PetcareRequest request,
    required AppUser helper,
    required String message,
  }) {
    return _runAction(helper.neighborhoodId, helper.id, () async {
      await _petcare.offerHelp(
        requestId: request.id,
        helperId: helper.id,
        message: message,
      );
      await _notifications.push(
        recipientId: request.requesterId,
        title: 'Hilfe bei der Tierbetreuung',
        message: '${helper.fullName} möchte sich um ${request.petType} kümmern.',
        category: NotificationCategory.care,
        triggeredByUserId: helper.id,
      );
      await loadOffers(request.id, isChildcare: false);
    });
  }

  Future<bool> withdrawPetcareHelp({
    required PetcareRequest request,
    required AppUser helper,
  }) {
    return _runAction(helper.neighborhoodId, helper.id, () async {
      await _petcare.withdrawHelp(requestId: request.id, helperId: helper.id);
      await loadOffers(request.id, isChildcare: false);
    });
  }

  Future<bool> closePetcareRequest({
    required PetcareRequest request,
    required AppUser requester,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _petcare.markAsCovered(
        requestId: request.id,
        requesterId: requester.id,
      );
      final helpers = offersFor(request.id, isChildcare: false)
          .map((offer) => offer.helperId)
          .toList();
      await _notifications.pushToMany(
        recipientIds: helpers,
        title: 'Tierbetreuung geklärt',
        message: '${requester.fullName} hat die Betreuung geklärt. '
            'Danke für dein Angebot!',
        category: NotificationCategory.care,
        triggeredByUserId: requester.id,
      );
    });
  }

  Future<bool> deletePetcareRequest({
    required PetcareRequest request,
    required AppUser requester,
  }) {
    return _runAction(requester.neighborhoodId, requester.id, () async {
      await _petcare.deleteRequest(
        requestId: request.id,
        requesterId: requester.id,
      );
      _offerCache.remove(_cacheKey(request.id, false));
    });
  }

  void reset() {
    _childcareRequests = const <ChildcareRequest>[];
    _petcareRequests = const <PetcareRequest>[];
    _offerCache.clear();
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  String _cacheKey(int requestId, bool isChildcare) =>
      '${isChildcare ? 'child' : 'pet'}#$requestId';

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
      _childcareRequests = await _childcare.loadAll(
        neighborhoodId: neighborhoodId,
        currentUserId: userId,
      );
      _petcareRequests = await _petcare.loadAll(
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
    AppLogger.instance.warning(_logTag, 'Care action failed.', error);
    notifyListeners();
  }
}
