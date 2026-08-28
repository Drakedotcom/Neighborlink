import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../state/care_controller.dart';
import '../../state/event_controller.dart';
import '../../state/feed_controller.dart';
import '../../state/food_controller.dart';
import '../../state/furniture_controller.dart';
import '../../state/neighborhood_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/ride_controller.dart';
import '../screens/care/childcare_screen.dart';
import '../screens/care/petcare_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/feed/community_feed_screen.dart';
import '../screens/food/food_sharing_screen.dart';
import '../screens/furniture/furniture_screen.dart';
import '../screens/neighborhood/neighborhood_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/rides/ride_sharing_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_tile.dart';
import 'app_destinations.dart';

///NiS
/// Width from which the sidebar is displayed permanently.
const double _sidebarBreakpoint = 1000;

/// Root widget shown to a signed-in user.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  AppDestination _current = AppDestination.dashboard;

  @override
  void initState() {
    super.initState();
    // Load the data every screen depends on right after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSharedData());
  }

  /// Loads neighbourhood members and the notification inbox once per session.
  Future<void> _loadSharedData() async {
    final auth = context.read<AuthController>();
    final user = auth.currentUser;
    if (user == null) return;

    await Future.wait<void>(<Future<void>>[
      context.read<NeighborhoodController>().load(user.neighborhoodId),
      context.read<NotificationController>().load(user.id),
    ]);
  }

  /// Allows child screens to jump to another module (used by the dashboard).
  void navigateTo(AppDestination destination) {
    if (_current == destination) return;
    setState(() => _current = destination);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;

    return Scaffold(
      // On narrow windows the same navigation is available through a drawer.
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: _NavigationSidebar(
                  current: _current,
                  isExtended: true,
                  onSelect: (destination) {
                    Navigator.of(context).pop();
                    navigateTo(destination);
                  },
                ),
              ),
            ),
      appBar: _buildAppBar(context, isWide),
      body: Row(
        children: <Widget>[
          if (isWide)
            _NavigationSidebar(
              current: _current,
              isExtended: true,
              onSelect: navigateTo,
            ),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(
            child: SafeArea(
              top: false,
              child: _buildCurrentScreen(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isWide) {
    final auth = context.watch<AuthController>();
    final unreadCount = context.watch<NotificationController>().unreadCount;
    final neighborhood = auth.currentNeighborhood;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_current.label),
          Text(
            _current.subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (neighborhood != null && isWide)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(neighborhood.displayName),
            ),
          ),
        IconButton(
          tooltip: 'Benachrichtigungen',
          onPressed: () => navigateTo(AppDestination.notifications),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: AppColors.danger,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        const SizedBox(width: 4),
        _ProfileMenu(onNavigate: navigateTo),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Builds the currently selected module screen.
  ///
  /// A `switch` instead of an [IndexedStack] keeps memory usage low and makes
  /// every screen reload its data when the user comes back to it.
  Widget _buildCurrentScreen() {
    return switch (_current) {
      AppDestination.dashboard => DashboardScreen(onNavigate: navigateTo),
      AppDestination.feed => const CommunityFeedScreen(),
      AppDestination.foodSharing => const FoodSharingScreen(),
      AppDestination.furniture => const FurnitureScreen(),
      AppDestination.rides => const RideSharingScreen(),
      AppDestination.events => const EventsScreen(),
      AppDestination.childCare => const ChildcareScreen(),
      AppDestination.petCare => const PetcareScreen(),
      AppDestination.neighborhood => const NeighborhoodScreen(),
      AppDestination.notifications => const NotificationsScreen(),
      AppDestination.profile => const ProfileScreen(),
    };
  }
}

/// The green sidebar with the grouped destination list.
class _NavigationSidebar extends StatelessWidget {
  const _NavigationSidebar({
    required this.current,
    required this.onSelect,
    required this.isExtended,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationController>().unreadCount;

    // Group the destinations so we can render a caption per section.
    final grouped = <DestinationGroup, List<AppDestination>>{};
    for (final destination in AppDestination.values) {
      grouped.putIfAbsent(destination.group, () => <AppDestination>[]).add(destination);
    }

    return Container(
      width: 250,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SidebarBrand(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                for (final entry in grouped.entries) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      entry.key.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                  for (final destination in entry.value)
                    _SidebarItem(
                      destination: destination,
                      isSelected: destination == current,
                      badgeCount: destination == AppDestination.notifications
                          ? unreadCount
                          : 0,
                      onTap: () => onSelect(destination),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const _SidebarFooter(),
        ],
      ),
    );
  }
}

/// Logo block at the top of the sidebar.
class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.diversity_3, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'NeighborLink',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Gemeinsam. Lokal.',
                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the sidebar.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: isSelected ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed-in user block at the bottom of the sidebar.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          InitialsAvatar(initials: user.initials, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  user.postalCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Abmelden',
            iconSize: 19,
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

/// Avatar menu in the app bar.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onNavigate});

  final ValueChanged<AppDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: user.fullName,
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onNavigate(AppDestination.profile);
          case 'neighborhood':
            onNavigate(AppDestination.neighborhood);
          case 'logout':
            _signOut(context);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline, size: 20),
            title: Text('Profil'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'neighborhood',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.groups_2_outlined, size: 20),
            title: Text('Nachbarschaft'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, size: 20, color: AppColors.danger),
            title: Text('Abmelden', style: TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InitialsAvatar(initials: user.initials, size: 34),
      ),
    );
  }
}

/// Signs the user out and clears every module controller.
///
/// Central helper so that no module forgets to reset its state — otherwise
/// the next user would briefly see the previous user's data.
void _signOut(BuildContext context) {
  context.read<FeedController>().reset();
  context.read<FoodController>().reset();
  context.read<FurnitureController>().reset();
  context.read<RideController>().reset();
  context.read<EventController>().reset();
  context.read<CareController>().reset();
  context.read<NeighborhoodController>().reset();
  context.read<NotificationController>().reset();
  context.read<AuthController>().signOut();
}
