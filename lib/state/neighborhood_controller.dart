import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_user.dart';
import '../data/models/neighborhood.dart';
import '../data/repositories/neighborhood_repository.dart';
import 'auth_controller.dart' show ViewState;

///LuS
class NeighborhoodController extends ChangeNotifier {
  NeighborhoodController({
    NeighborhoodRepository repository = const NeighborhoodRepository(),
  }) : _repository = repository;

  static const String _logTag = 'NeighborhoodController';

  final NeighborhoodRepository _repository;

  Neighborhood? _neighborhood;
  List<AppUser> _members = const <AppUser>[];
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  Neighborhood? get neighborhood => _neighborhood;
  List<AppUser> get members => _members;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;

  int otherMemberCount(int currentUserId) =>
      _members.where((member) => member.id != currentUserId).length;

  Future<void> load(int neighborhoodId) async {
    _state = ViewState.busy;
    _errorMessage = null;
    notifyListeners();

    try {
      _neighborhood = await _repository.findById(neighborhoodId);
      _members = await _repository.loadMembers(neighborhoodId);
      _state = ViewState.idle;
      AppLogger.instance.debug(
        _logTag,
        'Loaded ${_members.length} members of neighbourhood #$neighborhoodId.',
      );
    } on AppException catch (error) {
      _errorMessage = error.message;
      _state = ViewState.failure;
      AppLogger.instance.warning(_logTag, 'Loading failed.', error);
    }
    notifyListeners();
  }

  ///used for module notification
  List<int> get memberIds =>
      _members.map((member) => member.id).toList(growable: false);

  String displayNameOf(int userId) {
    for (final member in _members) {
      if (member.id == userId) return member.fullName;
    }
    return 'Nachbar:in';
  }

  void reset() {
    _neighborhood = null;
    _members = const <AppUser>[];
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}