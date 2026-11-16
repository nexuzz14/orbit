# Orbit Android Release ProGuard / R8 Rules
# Mencegah R8 Full Mode menghapus konstruktor dan DAO hasil generasi Room untuk WorkManager
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
    *;
}
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase_Impl$* { *; }
-keep class androidx.work.impl.model.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
    *;
}
-keep class * extends androidx.work.InputMerger {
    public <init>();
}
-keep class * extends androidx.startup.Initializer {
    public <init>();
    *;
}

# Jaga seluruh komponen Android native Orbit (Widget Provider, Worker, NotificationListener, MainActivity)
-keep class id.my.nabilcf.orbit_app.** { *; }

# Jaga plugin notifikasi lokal & serialisasi JSON detail notifikasi
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { *; }

# Jaga ML Kit Text Recognition & Biometric
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class androidx.biometric.** { *; }
