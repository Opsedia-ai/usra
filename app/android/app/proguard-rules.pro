# R8 rules for release builds. The Flutter Gradle plugin adds this file to
# the release build type next to Flutter's own rules; most plugins ship their
# own consumer rules, these cover the gaps.

# ML Kit text recognition: only the Latin model is bundled (Arabic isn't
# offered by ML Kit). The plugin references the Chinese, Devanagari,
# Japanese and Korean recognizer options, which aren't on the classpath.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications stores scheduled reminders as JSON with Gson
# and reads them back after a reboot (ScheduledNotificationBootReceiver).
# Gson ships its own rules, but the plugin's model classes are reflected on
# by field name: keep them, or re-armed reminders come back empty.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# sqlite3mc (SQLite3 Multiple Ciphers) is loaded by Dart FFI by library name,
# not through Java, so R8 never touches it; nothing to keep.

# home_widget: the widget provider is named in the manifest (kept
# automatically) and talks to Dart through method channels.
-keep class es.antonborri.home_widget.** { *; }

# flutter_secure_storage: Android Keystore / Tink-backed storage holding the
# database key. Losing these classes to R8 would lock users out of their data.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
