import 'package:flutter/widgets.dart';
import 'app_lock_service.dart';

/// Observer Lifecycle Aplikasi untuk Auto-Lock
/// Sesuai PRD GAMINI.md Bagian 7.6:
/// Mengunci aplikasi secara otomatis jika berada di latar belakang (background) > 30 detik.
class AppLifecycleManager with WidgetsBindingObserver {
  final AppLockService _appLockService;
  DateTime? _pausedAt;

  static const Duration autoLockTimeout = Duration(seconds: 30);

  AppLifecycleManager(this._appLockService) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        if (elapsed >= autoLockTimeout) {
          _appLockService.lock();
        }
        _pausedAt = null;
      }
    }
  }
}
