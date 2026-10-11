# Google ML Kit Text Recognition & Document Scanner
# Abaikan modul bahasa opsional (Chinese, Japanese, Korean, Devanagari) yang sengaja tidak di-bundle
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.documentscanner.**
-dontwarn com.google.android.gms.**

-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.documentscanner.** { *; }

# Flutter Native Plugins & Desugaring
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn java.lang.invoke.**
-dontwarn com.google.android.play.core.**

