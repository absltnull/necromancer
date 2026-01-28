# keep MainActivity, critical!
-keep class xyz.absnull.necromancer.MainActivity { *; }

# keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**    { *; }
-keep class io.flutter.view.**    { *; }
-keep class io.flutter.**         { *; }
-keep class io.flutter.plugins.** { *; }

# file picker
-keep class com.angryredplanet.** { *; }
-keep class io.flutter.plugins.filepicker.** { *; }

# http / dio / json_serializable
-keep class * implements com.google.gson.** { *; }
-keep class * implements java.io.Serializable { *; }
-keepattributes Signature
-keepattributes *Annotation*

-keep class com.angryredplanet.** { *; }

# keep Flutter's split install classes
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# also keep Flutter embedding classes that reference them
-keep class io.flutter.embedding.** { *; }

# keep the MainActivity stuff (again, for safety)
-keep class xyz.absnull.necromancer.MainActivity { *; }
-keepclassmembers class xyz.absnull.necromancer.MainActivity { *; }

# broader Flutter embedding keeps
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }