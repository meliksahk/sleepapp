package com.nocta.nocta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * `AlarmManager` alarmı ateşlendiğinde OS bunu çalıştırır — **uygulama süreci ölü olsa
 * bile** (#174). Tek işi tam-ekran uyandırma bildirimini tetiklemek. Manifest'te
 * `<receiver>` olarak kayıtlı (exported=false: yalnızca OS'un kurduğumuz alarmı tetikler).
 */
class NightAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NightAlarm.fire(context)
    }
}
