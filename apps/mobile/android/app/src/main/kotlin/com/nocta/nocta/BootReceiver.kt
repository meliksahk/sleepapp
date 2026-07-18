package com.nocta.nocta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Cihaz yeniden başladığında kalıcı gece alarmını yeniden kurar (#175).
 *
 * ## Neden gerekli
 *
 * `AlarmManager` kayıtları cihaz reboot'unda SİLİNİR. Kullanıcı gece alarm kurup
 * uyurken telefon gündüz (OTA güncellemesi, güç kesintisi) yeniden başlarsa alarm
 * sessizce kaybolurdu — bir uyku app'inin en pahalı hatası. Bu receiver, `NightAlarm`'ın
 * native SharedPreferences'a yazdığı son-tarihi okuyup alarmı yeniden kurar.
 *
 * Boot'ta Flutter engine ÇALIŞMAZ; bu yüzden reschedule tamamen native olmalı (Dart'a
 * dokunmadan). Manifest'te `BOOT_COMPLETED` + OEM `QUICKBOOT_POWERON` filtreleriyle kayıtlı.
 *
 * **Sınır:** `BOOT_COMPLETED`, uygulama en az bir kez çalıştıktan sonra gelir (Android
 * stopped-state kuralı). Alarm kurmak zaten uygulamayı açtığından bu koşul sağlanır.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            -> {
                Log.i(NightAlarm.TAG, "boot received: ${intent.action}")
                NightAlarm.reschedulePersisted(context.applicationContext)
            }
        }
    }
}
