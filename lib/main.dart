import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tzdb;

import 'app/app.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tangkap error sinkron dan asinkron secara global untuk mencegah force close (crash langsung keluar)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught Platform Async Error: $error\n$stack');
    return true; // Mencegah aplikasi crash ke home screen
  };

  // Inisialisasi timezone database — WAJIB sebelum NotificationService
  try {
    tz.initializeTimeZones();
    try {
      final localTzInfo = await FlutterTimezone.getLocalTimezone();
      tzdb.setLocalLocation(tzdb.getLocation(localTzInfo.identifier));
    } catch (e) {
      // Fallback ke Asia/Jakarta jika gagal detect timezone perangkat
      try {
        tzdb.setLocalLocation(tzdb.getLocation('Asia/Jakarta'));
      } catch (_) {}
      debugPrint('Timezone detection fallback: $e');
    }
  } catch (e) {
    debugPrint('Timezone initialization failed (non-fatal): $e');
  }

  // Inisialisasi format tanggal bahasa Indonesia
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting initialization failed (non-fatal): $e');
  }

  // Inisialisasi Supabase (opsional — hanya jika dikonfigurasi)
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (e) {
      debugPrint('Supabase init skipped/error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: AnakKostApp(),
    ),
  );
}
