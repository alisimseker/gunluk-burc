package com.alisimseker.gunluk_burc

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Uygulama kapalıyken de çalışır:
 *  - Her gece 00:01 civarı ve ayrıca 3 saatte bir yorumları indirir (internet yoksa önbelleği kullanır)
 *  - Bugünün yorumunu kilit ekranında görünen kalıcı bildirim olarak gösterir/günceller
 * Telefon yeniden başlatılınca WorkManager işleri kendiliğinden geri gelir; BootReceiver bildirimi hemen geri koyar.
 */
class DailyWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        if (Store.sign(ctx) == null) return Result.success()
        Store.refresh(ctx)
        showToday(ctx)
        scheduleMidnight(ctx)
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "gunluk_burc"
        private const val NOTIF_ID = 1001
        private const val PERIODIC = "burc_periodic"
        private const val MIDNIGHT = "burc_midnight"
        private const val NOW = "burc_now"

        fun scheduleAll(ctx: Context) {
            val req = PeriodicWorkRequestBuilder<DailyWorker>(3, TimeUnit.HOURS).build()
            WorkManager.getInstance(ctx)
                .enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, req)
            scheduleMidnight(ctx)
        }

        fun runNow(ctx: Context) {
            WorkManager.getInstance(ctx).enqueueUniqueWork(
                NOW, ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<DailyWorker>().build()
            )
        }

        fun scheduleMidnight(ctx: Context) {
            val next = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
            }
            val delay = next.timeInMillis - System.currentTimeMillis()
            val req = OneTimeWorkRequestBuilder<DailyWorker>()
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.NOT_REQUIRED).build())
                .build()
            // Hedef günün tek/çift olmasına göre ad: gece yarısı çalışan iş, kendisini iptal etmeden
            // bir sonraki geceyi planlayabilsin.
            val name = MIDNIGHT + "_" + (next.get(Calendar.DAY_OF_YEAR) % 2)
            WorkManager.getInstance(ctx).enqueueUniqueWork(name, ExistingWorkPolicy.REPLACE, req)
        }

        fun showToday(ctx: Context) {
            if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) return
            val r = Store.today(ctx) ?: return
            createChannel(ctx)

            val open = PendingIntent.getActivity(
                ctx, 0,
                Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val n = NotificationCompat.Builder(ctx, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_burc)
                .setContentTitle("✨ ${r.motivation}")
                .setContentText(r.short)
                .setStyle(NotificationCompat.BigTextStyle()
                    .setBigContentTitle("${r.signName} · ✨ ${r.motivation}")
                    .bigText(r.text))
                .setSubText(r.signName)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(false)
                .setShowWhen(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
                .setContentIntent(open)
                .build()
            try {
                NotificationManagerCompat.from(ctx).notify(NOTIF_ID, n)
            } catch (_: SecurityException) {
            }
        }

        private fun createChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) != null) return
            // Varsayılan önem + sessiz: kilit ekranında görünür ama ses/titreşim yapmaz
            val ch = NotificationChannel(CHANNEL, "Günlük burç yorumu", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Kilit ekranında ve bildirim çubuğunda duran günlük yorum"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
        }
    }
}

/** Telefon açıldığında / uygulama güncellendiğinde bildirimi hemen geri getirir. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Store.sign(context) == null) return
        DailyWorker.scheduleAll(context)
        DailyWorker.runNow(context)
    }
}
