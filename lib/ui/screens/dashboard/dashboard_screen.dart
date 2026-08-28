import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/neighborhood_event.dart';
import '../../../state/auth_controller.dart';
import '../../../state/care_controller.dart';
import '../../../state/event_controller.dart';
import '../../../state/feed_controller.dart';
import '../../../state/food_controller.dart';
import '../../../state/furniture_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../../state/notification_controller.dart';
import '../../../state/ride_controller.dart';
import '../../shell/app_destinations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_tile.dart';

///NiS
/// Overview screen with the key figures of the neighbourhood.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Callback into the shell so the tiles can act as shortcuts.
  final ValueChanged<AppDestination> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEverything());
  }

  /// Loads the data of every module in parallel.
  Future<void> _loadEverything() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    await Future.wait<void>(<Future<void>>[
      context.read<FeedController>().load(user.neighborhoodId),
      context.read<FoodController>().load(
        neighborhoodId: user.neighborhoodId,
        userId: user.id,
      ),
      context.read<FurnitureController>().load(
        neighborhoodId: user.neighborhoodId,
        userId: user.id,
      ),
      context.read<RideController>().load(
        neighborhoodId: user.neighborhoodId,
        userId: user.id,
      ),
      context.read<EventController>().load(
        neighborhoodId: user.neighborhoodId,
        userId: user.id,
      ),
      context.read<CareController>().load(
        neighborhoodId: user.neighborhoodId,
        userId: user.id,
      ),
      context.read<NeighborhoodController>().load(user.neighborhoodId),
      context.read<NotificationController>().load(user.id),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final neighborhood = context.watch<NeighborhoodController>();
    final food = context.watch<FoodController>();
    final furniture = context.watch<FurnitureController>();
    final rides = context.watch<RideController>();
    final events = context.watch<EventController>();
    final care = context.watch<CareController>();
    final feed = context.watch<FeedController>();
    final notifications = context.watch<NotificationController>();

    final int activeOfferCount =
        food.availableCount +
        furniture.availableCount +
        rides.ridesWithFreeSeats +
        care.openChildcareCount +
        care.openPetcareCount;

    return RefreshIndicator(
      onRefresh: _loadEverything,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gap * 1.5),
        children: <Widget>[
          _WelcomeBanner(
            firstName: user.firstName,
            neighborhoodName:
                neighborhood.neighborhood?.displayName ?? user.postalCode,
            memberCount: neighborhood.otherMemberCount(user.id),
          ),
          const SizedBox(height: AppTheme.gap * 1.5),

          // --- Key figures ------------------------------------------------
          const SectionHeader(
            title: 'Kennzahlen',
            subtitle: 'Der aktuelle Stand in deiner Nachbarschaft',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive grid: 4 columns on desktop, 2 on narrow windows.
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;

              final tiles = <Widget>[
                StatTile(
                    icon: Icons.groups_2_outlined,
                    value: '${neighborhood.otherMemberCount(user.id)}',
                    label: 'Nachbar:innen',
                    accentColor: AppColors.primary,
                    caption: neighborhood.neighborhood?.displayName,
                    onTap: () => widget.onNavigate(AppDestination.neighborhood),
                  ),
                  StatTile(
                    icon: Icons.volunteer_activism_outlined,
                    value: '$activeOfferCount',
                    label: 'Aktive Angebote',
                    accentColor: AppColors.accent,
                    caption:
                        '${food.availableCount} Lebensmittel · '
                        '${furniture.availableCount} Möbel · '
                        '${rides.ridesWithFreeSeats} Fahrten',
                    onTap: () => widget.onNavigate(AppDestination.foodSharing),
                  ),
                  StatTile(
                    icon: Icons.celebration_outlined,
                    value: '${events.upcomingEvents.length}',
                    label: 'Kommende Events',
                    accentColor: AppColors.categoryEvent,
                    caption: events.upcomingEvents.isEmpty
                        ? 'Noch nichts geplant'
                        : 'Nächstes: ${events.upcomingEvents.first.title}',
                    onTap: () => widget.onNavigate(AppDestination.events),
                  ),
                  StatTile(
                    icon: Icons.notifications_active_outlined,
                    value: '${notifications.unreadCount}',
                    label: 'Neue Nachrichten',
                    accentColor: AppColors.danger,
                    caption: notifications.unreadCount == 0
                        ? 'Alles gelesen'
                        : 'Ungelesen in deinem Postfach',
                    onTap: () => widget.onNavigate(AppDestination.notifications),
                  ),
              ];

              // Auf dem Handy passt nur eine Spalte. Ein festes Seitenverhältnis
              // würde dort die Kachel abschneiden, sobald die Bildunterschrift
              // zweizeilig wird – deshalb hier untereinander mit natürlicher Höhe.
              if (columns == 1) {
                return Column(
                  children: <Widget>[
                    for (var i = 0; i < tiles.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 12),
                      tiles[i],
                    ],
                  ],
                );
              }

              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: tiles,
              );
            },
          ),

          const SizedBox(height: AppTheme.gap * 2),

          // --- Two column detail area --------------------------------------
          LayoutBuilder(
            builder: (context, constraints) {
              final upcoming = events.upcomingEvents.take(3).toList();
              final unread = notifications.unreadNotifications.take(4).toList();

              final eventsCard = _UpcomingEventsCard(
                events: upcoming,
                onShowAll: () => widget.onNavigate(AppDestination.events),
              );
              final notificationsCard = _RecentNotificationsCard(
                notifications: unread,
                onShowAll: () =>
                    widget.onNavigate(AppDestination.notifications),
              );

              if (constraints.maxWidth < 860) {
                return Column(
                  children: <Widget>[
                    eventsCard,
                    const SizedBox(height: AppTheme.gap),
                    notificationsCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: eventsCard),
                  const SizedBox(width: AppTheme.gap),
                  Expanded(child: notificationsCard),
                ],
              );
            },
          ),

          const SizedBox(height: AppTheme.gap * 2),

          // --- Quick actions -------------------------------------------------
          const SectionHeader(
            title: 'Schnellzugriff',
            subtitle: 'Direkt zu den Modulen springen',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _QuickAction(
                icon: Icons.restaurant_outlined,
                label: 'Lebensmittel teilen',
                count: food.availableCount,
                color: AppColors.categoryFood,
                onTap: () => widget.onNavigate(AppDestination.foodSharing),
              ),
              _QuickAction(
                icon: Icons.chair_outlined,
                label: 'Möbel verschenken',
                count: furniture.availableCount,
                color: AppColors.categoryFurniture,
                onTap: () => widget.onNavigate(AppDestination.furniture),
              ),
              _QuickAction(
                icon: Icons.directions_car_outlined,
                label: 'Mitfahren',
                count: rides.ridesWithFreeSeats,
                color: AppColors.categoryRide,
                onTap: () => widget.onNavigate(AppDestination.rides),
              ),
              _QuickAction(
                icon: Icons.child_care_outlined,
                label: 'Kinderbetreuung',
                count: care.openChildcareCount,
                color: AppColors.categoryChildCare,
                onTap: () => widget.onNavigate(AppDestination.childCare),
              ),
              _QuickAction(
                icon: Icons.pets_outlined,
                label: 'Tierbetreuung',
                count: care.openPetcareCount,
                color: AppColors.categoryPetCare,
                onTap: () => widget.onNavigate(AppDestination.petCare),
              ),
              _QuickAction(
                icon: Icons.forum_outlined,
                label: 'Community Feed',
                count: feed.totalPostCount,
                color: AppColors.categoryGeneral,
                onTap: () => widget.onNavigate(AppDestination.feed),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.gap),
        ],
      ),
    );
  }
}

/// Green gradient greeting card at the top of the dashboard.
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.firstName,
    required this.neighborhoodName,
    required this.memberCount,
  });

  final String firstName;
  final String neighborhoodName;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.gap * 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primaryDark, AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hallo $firstName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  memberCount == 0
                      ? 'Du bist die erste Person in $neighborhoodName. '
                            'Lade deine Nachbarn ein!'
                      : 'In $neighborhoodName sind $memberCount '
                            '${memberCount == 1 ? 'Nachbar:in' : 'Nachbar:innen'} '
                            'mit dir aktiv.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.gap),
          const Icon(Icons.eco_outlined, color: Colors.white24, size: 62),
        ],
      ),
    );
  }
}

/// List of the next events.
class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({required this.events, required this.onShowAll});

  final List<NeighborhoodEvent> events;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: 'Kommende Events',
              trailing: TextButton(
                onPressed: onShowAll,
                child: const Text('Alle'),
              ),
            ),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Aktuell ist kein Event geplant. Wie wäre es mit einem '
                  'Nachbarschaftstreffen?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              DateFormatter.prettyDateShort(event.eventDate),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              event.eventTime,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              event.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${event.location} · ${event.participantCount} '
                              'Teilnehmende',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        event.countdownLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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

/// Preview of the unread notifications.
class _RecentNotificationsCard extends StatelessWidget {
  const _RecentNotificationsCard({
    required this.notifications,
    required this.onShowAll,
  });

  final List<AppNotification> notifications;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: 'Neue Benachrichtigungen',
              trailing: TextButton(
                onPressed: onShowAll,
                child: const Text('Postfach'),
              ),
            ),
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.statusAvailable,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Du bist auf dem neuesten Stand.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final notification in notifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5, right: 10),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              notification.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              notification.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormatter.relative(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textDisabled,
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

/// Small shortcut button in the quick action row.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
