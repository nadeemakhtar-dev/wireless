import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wireless/screens/MainScreen.dart';
import 'package:wireless/screens/SplashScreen.dart';

import '../screens/SettingsScreen.dart';


class AppRouter {
  // Private constructor
  AppRouter._internal();

  // Singleton instance
  static final AppRouter _instance = AppRouter._internal();

  // Getter for instance
  static AppRouter get instance => _instance;

  // GoRouter instance
  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      //settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

    ],
  );
}
