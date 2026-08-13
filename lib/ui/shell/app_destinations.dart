import 'package:flutter/material.dart';

///NiS
/// Every top level destination of the application.
///
/// The enum is the single source of truth for the sidebar, the mobile drawer
/// and the app bar title, so adding a screen means touching exactly one place.
enum AppDestination {
  dashboard('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard, DestinationGroup.overview),
  feed('Community Feed', Icons.forum_outlined, Icons.forum, DestinationGroup.overview),

  foodSharing('Food Sharing', Icons.restaurant_outlined, Icons.restaurant, DestinationGroup.sharing),
  furniture('Möbel', Icons.chair_outlined, Icons.chair, DestinationGroup.sharing),

  rides('Fahrgemeinschaften', Icons.directions_car_outlined, Icons.directions_car, DestinationGroup.community),
  events('Events', Icons.celebration_outlined, Icons.celebration, DestinationGroup.community),
  childCare('Kinderbetreuung', Icons.child_care_outlined, Icons.child_care, DestinationGroup.community),
  petCare('Tierbetreuung', Icons.pets_outlined, Icons.pets, DestinationGroup.community),

  neighborhood('Nachbarschaft', Icons.groups_2_outlined, Icons.groups_2, DestinationGroup.personal),
  notifications('Benachrichtigungen', Icons.notifications_outlined, Icons.notifications, DestinationGroup.personal),
  profile('Profil', Icons.person_outline, Icons.person, DestinationGroup.personal);

  const AppDestination(this.label, this.icon, this.selectedIcon, this.group);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final DestinationGroup group;

  /// Short explanation shown under the title in the app bar.
  String get subtitle => switch (this) {
    AppDestination.dashboard => 'Deine Nachbarschaft auf einen Blick',
    AppDestination.feed => 'Was gerade in der Nachbarschaft passiert',
    AppDestination.foodSharing => 'Lebensmittel teilen statt wegwerfen',
    AppDestination.furniture => 'Möbel und Gegenstände verschenken',
    AppDestination.rides => 'Gemeinsam fahren, Kosten und CO₂ sparen',
    AppDestination.events => 'Treffen und Aktionen in der Nachbarschaft',
    AppDestination.childCare => 'Gegenseitige Unterstützung bei den Kleinen',
    AppDestination.petCare => 'Betreuung für Haustiere organisieren',
    AppDestination.neighborhood => 'Alle Mitglieder deiner Nachbarschaft',
    AppDestination.notifications => 'Alles, was dich betrifft',
    AppDestination.profile => 'Deine Daten und Einstellungen',
  };
}

/// Logical grouping used to draw separators in the sidebar.
enum DestinationGroup {
  overview('Übersicht'),
  sharing('Teilen & Verschenken'),
  community('Nachbarschaftshilfe'),
  personal('Persönlich');

  const DestinationGroup(this.label);

  final String label;
}
