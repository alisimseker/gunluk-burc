# Mağaza (release) derlemesinde R8 küçültücüsünün silmemesi gerekenler

# WorkManager'ın Room veritabanı: oluşturucusu yansıma (reflection) ile çağrılır
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(...); }
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }

# Uygulamanın kendi yerel sınıfları (Worker'lar, BootReceiver, kanal)
-keep class com.alisimseker.gunluk_burc.** { *; }
-keep class * extends androidx.work.ListenableWorker { <init>(android.content.Context, androidx.work.WorkerParameters); }
