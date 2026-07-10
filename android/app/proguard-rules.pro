# ML Kit Text Recognition rules to ignore unused language models
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# General ML Kit rules
-dontwarn com.google.mlkit.vision.text.**

# ── Gson : conserver les types génériques pour éviter "Missing type parameter" ──
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ── flutter_local_notifications : conserver tous les modèles ──
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { *; }
