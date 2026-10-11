/// Konfigurasi Kredensial Supabase untuk Anak Kost
///
/// Anda dapat mengubah URL dan Anon Key langsung di file ini agar praktis saat pengembangan,
/// tanpa perlu mengetikkan parameter `--dart-define` yang panjang di terminal.
class SupabaseConfig {
  /// URL Proyek Supabase
  /// Catatan: Root URL proyek Supabase (bukan REST API URL).
  /// Sanitizer otomatis akan membersihkan '/rest/v1/' jika Anda tidak sengaja menyertakannya.
  static const String defaultUrl = 'https://ghqcrtukclhbqlxsebss.supabase.co';

  /// Anon / Public Key Proyek Supabase
  static const String defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdocWNydHVrY2xoYnFseHNlYnNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MTg2MjAsImV4cCI6MjEwNzE5NDYyMH0.lXOK1n4Aq53KqzyGD1jS4kGTFAUQusrrCPhfcMsKOzw';

  /// Mengambil URL aktif (Mendukung override via --dart-define atau fallback ke defaultUrl)
  static String get url {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    final raw = envUrl.isNotEmpty ? envUrl : defaultUrl;
    return sanitizeUrl(raw);
  }

  /// Mengambil Anon Key aktif (Mendukung override via --dart-define atau fallback ke defaultAnonKey)
  static String get anonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return envKey.isNotEmpty ? envKey : defaultAnonKey;
  }

  /// Memeriksa apakah konfigurasi Supabase sudah terisi
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Sanitasi URL Supabase:
  /// Menghilangkan trailing slash dan akhiran '/rest/v1' jika tidak sengaja tersalin dari dashboard.
  static String sanitizeUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.endsWith('/rest/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/rest/v1'.length);
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
