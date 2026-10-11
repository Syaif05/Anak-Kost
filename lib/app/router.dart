import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'mobile_shell.dart';
import '../core/providers/core_providers.dart';
import '../core/security/app_lock_service.dart';
import '../features/auth/presentation/lock_screen.dart';
import '../features/auth/presentation/setup_pin_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/finance/presentation/finance_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/agenda/presentation/agenda_screen.dart';
import '../features/bills/presentation/bills_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final lockService = ref.watch(appLockServiceProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: lockService,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isLockPath = loc == '/lock';
      final isSetupPath = loc == '/setup-pin';

      if (lockService.status == AppLockStatus.notConfigured) {
        return isSetupPath ? null : '/setup-pin';
      }

      if (lockService.isLocked) {
        return isLockPath ? null : '/lock';
      }

      // Jika sudah terbuka dan berada di layar lock/setup
      if (isLockPath || isSetupPath) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/setup-pin',
        builder: (context, state) => const SetupPinScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MobileShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Beranda
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Tab 2: Keuangan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceScreen(),
              ),
            ],
          ),
          // Tab 3: Kebutuhan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),
          // Tab 4: Agenda
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (context, state) => const AgendaScreen(),
              ),
            ],
          ),
          // Tab 5: Kost
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bills',
                builder: (context, state) => const BillsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
