import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'mobile_shell.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/finance/presentation/finance_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/agenda/presentation/agenda_screen.dart';
import '../features/bills/presentation/bills_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
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
