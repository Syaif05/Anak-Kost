# Google ML Kit Text Recognition & Document Scanner
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.documentscanner.**
-dontwarn com.google.android.gms.**
-dontwarn com.google_mlkit_commons.**
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_document_scanner.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Flutter Native Plugins & JNI
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class net.wolverinebeach.flutter_timezone.** { *; }
-keep class dev.dint.cryptography_flutter.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class com.github.dart_lang.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class androidx.biometric.** { *; }

# Desugaring & Reflection
-dontwarn java.lang.invoke.**
-dontwarn com.google.android.play.core.**
-dontwarn androidx.window.**


