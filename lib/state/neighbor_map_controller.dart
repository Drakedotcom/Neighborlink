import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';
import '../data/models/app_user.dart';
import 'auth_controller.dart' show ViewState;

///NiS
///Reviewed AI generated code
/// A single neighbour placed on the map at the geocoded address.
@immutable
class MappedNeighbor {
  const MappedNeighbor({
    required this.user,
    required this.position,
    required this.distanceInMeters,
  });

  final AppUser user;
  final LatLng position;
  final double distanceInMeters;

  /// Rounded on purpose — it is a straight-line distance and the geocoder is
  /// not metre-exact, so the label should not pretend to be either.
  String get distanceLabel {
    if (distanceInMeters < 1000) {
      final rounded = (distanceInMeters / 50).round() * 50;
      return 'ca. $rounded m entfernt';
    }
    final kilometres = (distanceInMeters / 1000).toStringAsFixed(1);
    return 'ca. ${kilometres.replaceAll('.', ',')} km entfernt';
  }
}

///AI generated code
/// Turns the postal addresses of a neighbourhood into map positions.
///
/// Deliberately holds no database of its own: coordinates are resolved once
/// per app start and cached in memory, which is plenty for a neighbourhood of
/// a few dozen people and keeps the schema untouched.
class NeighborMapController extends ChangeNotifier {
  static const String _logTag = 'NeighborMapController';

  static const Distance _distance = Distance();

  /// user id -> resolved coordinates. Static because the controller lives only
  /// as long as the map screen, but re-opening the map should still be instant.
  static final Map<int, LatLng> _cache = <int, LatLng>{};

  /// Created lazily so the platform plugin is registered by the time it runs.
  late final Geocoding _geocoding = Geocoding();

  ViewState _state = ViewState.idle;
  String? _errorMessage;
  LatLng? _homePosition;
  List<MappedNeighbor> _neighbors = const <MappedNeighbor>[];
  int _unresolvedCount = 0;

  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  LatLng? get homePosition => _homePosition;
  List<MappedNeighbor> get neighbors => _neighbors;

  /// Number of members whose address the geocoder could not place.
  int get unresolvedCount => _unresolvedCount;

  /// Resolves the signed-in user and every member of their neighbourhood.
  ///
  /// [cityName] comes from the neighbourhood and makes the lookup far more
  /// reliable than street plus postal code alone.
  Future<void> load({
    required AppUser currentUser,
    required List<AppUser> members,
    required String cityName,
  }) async {
    _state = ViewState.busy;
    _errorMessage = null;
    notifyListeners();

    final home = await _resolve(currentUser, cityName);
    if (home == null) {
      _state = ViewState.failure;
      _errorMessage =
          'Deine Adresse konnte nicht auf der Karte gefunden werden. '
          'Prüfe die Schreibweise in deinem Profil.';
      AppLogger.instance.warning(_logTag, 'Home address could not be resolved.');
      notifyListeners();
      return;
    }

    final resolved = <MappedNeighbor>[];
    var unresolved = 0;

    for (final member in members) {
      if (member.id == currentUser.id) continue;

      final position = await _resolve(member, cityName);
      if (position == null) {
        unresolved++;
        continue;
      }

      resolved.add(
        MappedNeighbor(
          user: member,
          position: position,
          distanceInMeters: _distance.as(LengthUnit.Meter, home, position),
        ),
      );
    }

    resolved.sort(
      (a, b) => a.distanceInMeters.compareTo(b.distanceInMeters),
    );

    _homePosition = home;
    _neighbors = List<MappedNeighbor>.unmodifiable(resolved);
    _unresolvedCount = unresolved;
    _state = ViewState.idle;

    AppLogger.instance.info(
      _logTag,
      'Placed ${resolved.length} neighbours, $unresolved could not be resolved.',
    );
    notifyListeners();
  }

  /// Looks up one address, using the in-memory cache when possible.
  Future<LatLng?> _resolve(AppUser user, String cityName) async {
    final cached = _cache[user.id];
    if (cached != null) return cached;

    final query = '${user.streetAddress}, ${user.postalCode} $cityName';
    try {
      final locations = await _geocoding.locationFromAddress(query);
      if (locations.isEmpty) {
        AppLogger.instance.debug(_logTag, 'No match for "$query".');
        return null;
      }
      final position = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      _cache[user.id] = position;
      return position;
    } catch (error) {
      // A single unknown street must not break the whole map.
      AppLogger.instance.warning(_logTag, 'Lookup failed for "$query".', error);
      return null;
    }
  }
}
