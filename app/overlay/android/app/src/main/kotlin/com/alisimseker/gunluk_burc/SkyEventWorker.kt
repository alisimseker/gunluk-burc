package com.alisimseker.gunluk_burc

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

/** Gökyüzü takvimi: olaydan bir gün önce gösterilen bildirim. */
class SkyEventWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) return Result.success()
        val title = inputData.getString("title") ?: return Result.success()
        val body = inputData.getString("body") ?: ""
        val id = inputData.getString("id") ?: title
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Gökyüzü takvimi", NotificationManager.IMPORTANCE_DEFAULT).apply {
                        description = "Retro, Yeniay, Dolunay ve tutulmalardan önce hatırlatma"
                    }
                )
            }
        }
        val open = PendingIntent.getActivity(
            ctx, 1,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_burc)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(2000 + (id.hashCode() and 0xFFFF), n)
        } catch (_: SecurityException) {
        }
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "gokyuzu_takvimi"
        private const val TAG = "sky_event"

        fun scheduleAll(ctx: Context, events: List<Map<String, Any?>>) {
            val wm = WorkManager.getInstance(ctx)
            wm.cancelAllWorkByTag(TAG)
            val now = System.currentTimeMillis()
            for (e in events) {
                val at = (e["at"] as? Number)?.toLong() ?: continue
                val id = e["id"] as? String ?: continue
                val delay = at - now
                if (delay <= 0) continue
                val req = OneTimeWorkRequestBuilder<SkyEventWorker>()
                    .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                    .addTag(TAG)
                    .setInputData(workDataOf("id" to id, "title" to e["title"], "body" to e["body"]))
                    .build()
                wm.enqueueUniqueWork("sky_$id", ExistingWorkPolicy.REPLACE, req)
            }
        }

        fun cancelAll(ctx: Context) = WorkManager.getInstance(ctx).cancelAllWorkByTag(TAG)
    }
}
