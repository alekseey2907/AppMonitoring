import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/devices/presentation/pages/device_detail_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/devices/presentation/pages/scan_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/alerts/presentation/pages/alerts_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../widgets/main_scaffold.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      
      // Login
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // BLE Scan
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanPage(),
      ),
      
      // Main App with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // Home/Dashboard
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          
          // Devices List
          GoRoute(
            path: '/devices',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DevicesPage(),
            ),
            routes: [
              GoRoute(
                path: ':deviceId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => DeviceDetailPage(
                  deviceId: state.pathParameters['deviceId']!,
                ),
              ),
            ],
          ),
          
          // Alerts
          GoRoute(
            path: '/alerts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AlertsPage(),
            ),
          ),
          
          // Analytics
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsPage(),
            ),
          ),
          
          // Settings
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
