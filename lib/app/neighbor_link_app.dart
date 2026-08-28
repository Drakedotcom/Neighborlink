import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/care_controller.dart';
import '../state/event_controller.dart';
import '../state/feed_controller.dart';
import '../state/food_controller.dart';
import '../state/furniture_controller.dart';
import '../state/neighborhood_controller.dart';
import '../state/notification_controller.dart';
import '../state/ride_controller.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/shell/app_shell.dart';
import '../ui/theme/app_theme.dart';

///LuS
///root widget
class NeighborLinkApp extends StatelessWidget {
  const NeighborLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ///done by LuS
        ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
        ChangeNotifierProvider<NeighborhoodController>(
          create: (_) => NeighborhoodController(),
        ),
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(),
        ),

        ///done by LuL
        ChangeNotifierProvider<FeedController>(create: (_) => FeedController()),
        ChangeNotifierProvider<FoodController>(create: (_) => FoodController()),
        ChangeNotifierProvider<FurnitureController>(
          create: (_) => FurnitureController(),
        ),

        ///done by NiS
        ChangeNotifierProvider<RideController>(create: (_) => RideController()),
        ChangeNotifierProvider<EventController>(
          create: (_) => EventController(),
        ),
        ChangeNotifierProvider<CareController>(create: (_) => CareController()),
      ],
      child: MaterialApp(
        title: 'NeighborLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const _SessionGate(),
      ),
    );
  }
}

///show login screen or app shell
///keep navigation off screens
class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthController, bool>(
      (controller) => controller.isSignedIn,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: isSignedIn
          ? const AppShell(key: ValueKey<String>('app-shell'))
          : const LoginScreen(key: ValueKey<String>('login')),
    );
  }
}