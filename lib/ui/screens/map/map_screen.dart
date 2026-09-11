import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../data/models/app_user.dart';
import '../../../state/auth_controller.dart';
import '../../../state/neighbor_map_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_tile.dart';

///NiS
///Rewieved AI generated code
/// Shows where the members of the own neighbourhood live and how far away
/// they are.
///
/// Opened as its own page from the app bar and brings its own controller, so
/// nothing outside this screen has to know about the map.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NeighborMapController>(
      create: (_) => NeighborMapController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Karte'),
              Text(
                'Wer wohnt wie weit entfernt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        body: const SafeArea(top: false, child: _MapView()),
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  static const double _defaultZoom = 13.5;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final neighborhood = context.read<NeighborhoodController>();
    final user = auth.currentUser;
    if (user == null) return;

    await context.read<NeighborMapController>().load(
      currentUser: user,
      members: neighborhood.members,
      cityName: neighborhood.neighborhood?.cityName ?? '',
    );
  }

  void _recenter(LatLng home) => _mapController.move(home, _defaultZoom);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NeighborMapController>();

    if (controller.isBusy) {
      return const _LoadingView();
    }

    if (controller.state == ViewState.failure) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.gap),
        child: ErrorBanner(
          message:
              controller.errorMessage ??
              'Die Karte konnte nicht geladen werden.',
          onRetry: _load,
        ),
      );
    }

    final home = controller.homePosition;
    if (home == null) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: 'Noch keine Karte',
        message:
            'Sobald deine Adresse hinterlegt ist, siehst du hier deine '
            'Nachbarschaft.',
        actionLabel: 'Erneut laden',
        onAction: _load,
      );
    }

    return Column(
      children: <Widget>[
        _MapHeader(
          neighbors: controller.neighbors.length,
          unresolved: controller.unresolvedCount,
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: home,
                  initialZoom: _defaultZoom,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'de.hochschule.neighborlink',
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      for (final neighbor in controller.neighbors)
                        Marker(
                          point: neighbor.position,
                          width: 46,
                          height: 46,
                          child: _NeighborMarker(
                            neighbor: neighbor,
                            onTap: () => _showNeighbor(neighbor),
                          ),
                        ),
                      Marker(
                        point: home,
                        width: 46,
                        height: 46,
                        child: const _HomeMarker(),
                      ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap'),
                  ),
                ],
              ),
              Positioned(
                right: AppTheme.gap,
                bottom: AppTheme.gap,
                child: FloatingActionButton.small(
                  tooltip: 'Auf meine Adresse zentrieren',
                  onPressed: () => _recenter(home),
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNeighbor(MappedNeighbor neighbor) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _NeighborSheet(neighbor: neighbor),
    );
  }
}

/// Shown while the addresses are being turned into coordinates.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: AppTheme.gap),
          Text(
            'Adressen werden ermittelt ...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Bar above the map with the region and how many people are shown.
class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.neighbors, required this.unresolved});

  final int neighbors;
  final int unresolved;

  @override
  Widget build(BuildContext context) {
    final neighborhood = context.watch<AuthController>().currentNeighborhood;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppTheme.gap, 12, AppTheme.gap, 12),
      color: AppColors.surface,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (neighborhood != null)
            Chip(
              avatar: const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(neighborhood.displayName),
            ),
          Text(
            neighbors == 1
                ? '1 Nachbar:in auf der Karte'
                : '$neighbors Nachbar:innen auf der Karte',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (unresolved > 0)
            Text(
              unresolved == 1
                  ? '· 1 Adresse konnte nicht zugeordnet werden'
                  : '· $unresolved Adressen konnten nicht zugeordnet werden',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
        ],
      ),
    );
  }
}

/// Exact pin for the signed-in user.
class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Deine Adresse',
      child: Icon(
        Icons.location_on,
        size: 40,
        color: AppColors.primaryDark,
        shadows: <Shadow>[
          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// Initials circle for everybody else, so neighbours are told apart from the
/// own pin at a glance.
class _NeighborMarker extends StatelessWidget {
  const _NeighborMarker({required this.neighbor, required this.onTap});

  final MappedNeighbor neighbor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          neighbor.user.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Details shown after tapping a neighbour.
class _NeighborSheet extends StatelessWidget {
  const _NeighborSheet({required this.neighbor});

  final MappedNeighbor neighbor;

  @override
  Widget build(BuildContext context) {
    final AppUser user = neighbor.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gap,
          0,
          AppTheme.gap,
          AppTheme.gap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                InitialsAvatar(initials: user.initials, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${user.streetAddress} · ${user.postalCode}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.gap),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.straighten,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    neighbor.distanceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
