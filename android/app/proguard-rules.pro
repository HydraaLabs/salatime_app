# The notification plugin persists these models with Gson. Preserve both JSON
# field names and subtype names so existing scheduled alarms survive an update.
-keep,allowoptimization class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson 2.8.9 reflects over generic TypeTokens when restoring scheduled alarms.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep,allowoptimization class com.google.gson.reflect.TypeToken { *; }
-keep,allowoptimization class * extends com.google.gson.reflect.TypeToken

# Other Gson models may use explicit serialized names; those names are the
# wire format, so their Java field names may still be obfuscated safely.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
