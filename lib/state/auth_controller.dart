import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_user.dart';
import '../data/models/neighborhood.dart';
import '../data/repositories/neighborhood_repository.dart';
import '../data/repositories/user_repository.dart';

/// LuS
enum ViewState { idle, busy, failure }

class AuthController extends ChangeNotifier {
  AuthController({
    UserRepository userRepository = const UserRepository(),
    NeighborhoodRepository neighborhoodRepository = const NeighborhoodRepository(),
  }) : _userRepository = userRepository,
       _neighborhoodRepository = neighborhoodRepository;

  static const String _logTag = 'AuthController';

  final UserRepository _userRepository;
  final NeighborhoodRepository _neighborhoodRepository;

  AppUser? _currentUser;
  Neighborhood? _currentNeighborhood;
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  Neighborhood? get currentNeighborhood => _currentNeighborhood;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  bool get isSignedIn => _currentUser != null;

  AppUser get requireUser {
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Für diese Aktion ist eine Anmeldung nötig.');
    }
    return user;
  }

  /// --- Commands -------------------------------------------------------------

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      final user = await _userRepository.authenticate(
        email: email,
        plainPassword: password,
      );
      await _establishSession(user);
      AppLogger.instance.info(_logTag, 'Session opened for #${user.id}.');
    });
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String streetAddress,
    required String postalCode,
    required String cityName,
  }) async {
    return _run(() async {
      final neighborhood = await _neighborhoodRepository.findOrCreateByPostalCode(
        postalCode.trim(),
        cityName: cityName.trim().isEmpty ? 'Unbekannter Ort' : cityName.trim(),
      );

      final user = await _userRepository.register(
        fullName: fullName,
        email: email,
        plainPassword: password,
        streetAddress: streetAddress,
        postalCode: postalCode,
        neighborhoodId: neighborhood.id,
      );

      await _establishSession(user);
      AppLogger.instance.info(
        _logTag,
        'Registration complete: user #${user.id} joined neighbourhood '
        '#${neighborhood.id}.',
      );
    });
  }

  Future<bool> updateProfile({
    required String fullName,
    required String streetAddress,
    required String aboutMe,
  }) async {
    return _run(() async {
      final updated = requireUser.copyWith(
        fullName: fullName.trim(),
        streetAddress: streetAddress.trim(),
        aboutMe: aboutMe.trim(),
      );
      _currentUser = await _userRepository.updateProfile(updated);
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _run(() async {
      await _userRepository.changePassword(
        userId: requireUser.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    });
  }

  ///no password asking again
  Future<void> refreshSession() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      _currentUser = await _userRepository.findById(user.id);
      _currentNeighborhood = await _neighborhoodRepository.findById(
        user.neighborhoodId,
      );
      notifyListeners();
    } on AppException catch (error) {
      AppLogger.instance.warning(_logTag, 'Session refresh failed.', error);
    }
  }

  void signOut() {
    AppLogger.instance.info(_logTag, 'Session closed for #${_currentUser?.id}.');
    _currentUser = null;
    _currentNeighborhood = null;
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _state = ViewState.idle;
    notifyListeners();
  }

  ///internals

  Future<void> _establishSession(AppUser user) async {
    _currentUser = user;
    _currentNeighborhood = await _neighborhoodRepository.findById(
      user.neighborhoodId,
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    _state = ViewState.busy;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on AppException catch (error) {
      ///expected
      _errorMessage = error.message;
      _state = ViewState.failure;
      AppLogger.instance.warning(_logTag, 'Operation failed: ${error.message}');
      notifyListeners();
      return false;
    } catch (error) {
      ///unexpected
      _errorMessage = 'Es ist ein unerwarteter Fehler aufgetreten.';
      _state = ViewState.failure;
      AppLogger.instance.error(_logTag, 'Unhandled error.', error);
      notifyListeners();
      return false;
    }
  }
}