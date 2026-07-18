package com.nocta.nocta

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Süreç-ölümüne dayanıklı alarm — #169'un native tail'i (#174). Dart `NightAlarmScheduler`
 * (`nocta/night_alarm` kanalı) son-tarihi buraya verir; `AlarmManager` onu İŞLETİM
 * SİSTEMİNE kaydeder → uygulama ölü olsa bile (Doze / OEM pil katili / OOM) OS `AlarmManager`
 * `NightAlarmReceiver`'ı tetikler ve tam-ekran uyandırma bildirimi çıkar.
 *
 * ## Neden setAlarmClock
 *
 * `setExactAndAllowWhileIdle` değil `setAlarmClock`: ikincisi GERÇEK uyandırma-alarmı
 * semantiğidir — kesin, Doze'da bile ateşlenir, sistem alarm ikonu gösterir ve alarm-saati
 * uygulamalarına en güçlü teslim garantisini verir. Bir uyku app'inin alarmı için doğru API.
 *
 * ## Doğrulama sınırı (dürüstlük)
 *
 * schedule → AlarmManager kaydı → receiver ateşleme zinciri emülatörde `dumpsys alarm` +
 * logcat ile doğrulanır. GERÇEK süreç-ölümü senaryosunda (OEM pil katili) ateşleme yalnızca
 * gerçek cihazlarda/koşullarda tam kanıtlanır; ama sistem-kaydı mekanizması burada kanıtlı.
 */
object NightAlarm {
    const val TAG = "NightAlarm"
    private const val REQUEST_CODE = 4172
    private const val CHANNEL_ID = "nocta_night_alarm"
    private const val NOTIFICATION_ID = 4173

    /** [epochMillis] anına sistemde kesin (Doze'da bile) uyandırma alarmı kurar. */
    fun schedule(context: Context, epochMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setAlarmClock(
            AlarmManager.AlarmClockInfo(epochMillis, activityIntent(context)),
            alarmIntent(context),
        )
        Log.i(TAG, "scheduled at $epochMillis")
    }

    /** Kurulu sistem alarmını iptal eder. Zaten yoksa sorun değil. */
    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(context))
        Log.i(TAG, "cancelled")
    }

    /** Alarm ateşlendiğinde (receiver'dan) tam-ekran uyandırma bildirimi gösterir. */
    fun fire(context: Context) {
        Log.i(TAG, "fired")
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(nm)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("NOCTA")
            .setContentText("Uyanma vakti")
            .setCategory(Notification.CATEGORY_ALARM)
            .setAutoCancel(true)
            // Ekran kilitliyken alarm-saati gibi tam-ekran aç (USE_FULL_SCREEN_INTENT).
            .setFullScreenIntent(activityIntent(context), true)
            .build()
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun ensureChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Gece alarmı",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "Süreç ölse bile uyandıran sistem alarmı"
            nm.createNotificationChannel(channel)
        }
    }

    /** Ateşlemede tetiklenecek broadcast (uygulama ölü olsa bile OS bunu çalıştırır). */
    private fun alarmIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, NightAlarmReceiver::class.java),
            pendingFlags(),
        )

    /** Alarm-saati "göster" hedefi + tam-ekran hedefi: uygulamayı açar. */
    private fun activityIntent(context: Context): PendingIntent =
        PendingIntent.getActivity(
            context,
            REQUEST_CODE + 1,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            pendingFlags(),
        )

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
