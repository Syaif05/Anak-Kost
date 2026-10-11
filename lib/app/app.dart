import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import '../core/providers/core_providers.dart';
import '../core/security/app_lifecycle_manager.dart';

class AnakKostApp extends ConsumerStatefulWidget {
  const AnakKostApp({super.key});

  @override
  ConsumerState<AnakKostApp> createState() => _AnakKostAppState();
}

class _AnakKostAppState extends ConsumerState<AnakKostApp> {
  AppLifecycleManager? _lifecycleManager;

  @override
  void initState() {
    super.initState();
    final lockService = ref.read(appLockServiceProvider);
    _lifecycleManager = AppLifecycleManager(lockService);
  }

  @override
  void dispose() {
    _lifecycleManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Anak Kost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(isAmoled: true),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
