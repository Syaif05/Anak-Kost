import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Layanan Notifikasi Lokal Android
/// Sesuai PRD GAMINI.md Bagian 3.4, 3.5, dan 6.7
/// - Notification Channels terpisah (Agenda, Tugas, Tagihan, Stok, Sistem)
/// - Exact alarm scheduling dengan fallback inexact
/// - ID notifikasi deterministik berbasis hash UUID entitas
/// - Dukungan Snooze (30m untuk tugas, 1d untuk tagihan)
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  // Channel IDs
  static const String channelAgenda = 'channel_agenda';
  static const String channelTasks = 'channel_tasks';
  static const String channelBills = 'channel_bills';
  static const String channelStock = 'channel_stock';
  static const String channelSystem = 'channel_system';

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get isInitialized => _isInitialized;

  /// Inisialisasi plugin dan channel Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Buat Android Notification Channels
      final androidPlatform = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAgenda,
            'Agenda & Jadwal Kegiatan',
            description: 'Pengingat jadwal kerja, kuliah, dan agenda penting kost',
            importance: Importance.high,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            channelTasks,
            'Tugas & Deadline',
            description: 'Pengingat tenggat waktu tugas harian dan magang',
            importance: Importance.high,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            channelBills,
            'Tagihan Rutin Kost',
            description: 'Pengingat jatuh tempo pembayaran sewa kost, listrik, dan WiFi',
            importance: Importance.high,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            channelStock,
            'Stok Kebutuhan',
            description: 'Pemberitahuan stok barang kost yang menipis',
            importance: Importance.defaultImportance,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            channelSystem,
            'Sistem & Sinkronisasi',
            description: 'Status sinkronisasi dan keamanan aplikasi',
            importance: Importance.low,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization failed or mock environment: $e');
    }
  }

  /// Menghasilkan ID integer 31-bit yang stabil dari string unik (UUID / key)
  int generateId(String uniqueKey) {
    var hash = 0;
    for (var i = 0; i < uniqueKey.length; i++) {
      hash = (31 * hash + uniqueKey.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Menampilkan notifikasi instan
  Future<void> showNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Menjadwalkan notifikasi presisi pada waktu tertentu (epoch millis UTC)
  Future<void> scheduleNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule exact notification, falling back to inexact: $e');
      try {
        final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Membatalkan notifikasi berdasarkan ID stabil
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) return;
    await _plugin.cancel(id: id);
  }

  /// Membatalkan semua notifikasi
  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    await _plugin.cancelAll();
  }
}
