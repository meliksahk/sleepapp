import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import '../../core/share/sharer.dart';
import '../../core/sleep_tracking/alarm_sound.dart';
import '../../core/sleep_tracking/night_alarm_scheduler.dart';
import '../../core/sleep_tracking/night_service.dart';
import '../../core/sleep_tracking/sleep_session_queue.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/sleep_tracking/record_mic_source.dart';
import '../../core/sleep_tracking/sleep_recorder.dart';
import 'sleep_controller.dart';
import 'sleep_mode_controller.dart';
import 'sleep_models.dart';

/// Uyku controller'ı — auth (oturum + refresh) + api client üzerine.
final sleepControllerProvider = Provider<SleepController>((ref) {
  return SleepController(
    ref.read(authControllerProvider),
    ref.read(apiClientProvider),
  );
});

/// Kullanıcının uyku serisi — home'da streak kartı bunu izler.
final streakProvider = FutureProvider<StreakStats>((ref) {
  return ref.read(sleepControllerProvider).streak();
});

/// En yeni uyku oturumları — geçmiş ekranı bunu izler.
final recentSleepSessionsProvider = FutureProvider<List<SleepSession>>((ref) {
  return ref.read(sleepControllerProvider).recentSessions();
});

/// Uyku istatistikleri — geçmiş ekranı başlığı bunu izler.
final sleepStatsProvider = FutureProvider<SleepStats>((ref) {
  return ref.read(sleepControllerProvider).stats();
});

/// Bir gecenin raporu (yoksa null) — gece raporu ekranı bunu izler.
final nightReportProvider = FutureProvider.family<NightReport?, String>((
  ref,
  nightDate,
) {
  return ref.read(sleepControllerProvider).nightReport(nightDate);
});

/// Son 7 gecenin trendi — geçmiş ekranı mini grafiği bunu izler.
final sleepTrendProvider = FutureProvider<WeeklyTrend>((ref) {
  return ref.read(sleepControllerProvider).weeklyTrend();
});

/// Uyku modu denetleyicisi — gerçek mikrofonla.
///
/// `RecordMicSource` üretim adaptörü; testler `SleepModeController`'ı doğrudan
/// sahte `MicSource` ile kurar (bu provider'a dokunmadan).
final sleepModeControllerProvider = Provider<SleepModeController>((ref) {
  return SleepModeController(
    // `logEnvelope: true` — eşikler gerçek gece kayıtlarıyla AYARLANMADI
    // (docs/04 §120 fixture'ları yok) ve veri olmadan ayarlanamaz. Zarf saniyede
    // 3 sayı; ham ses değil, konuşma geri getirilemez. Kullanıcı isterse paylaşır.
    recorder: SleepRecorder(mic: RecordMicSource(), logEnvelope: true),
    sleep: ref.read(sleepControllerProvider),
    // Android 14+ arka planda mikrofonu foreground service olmadan öldürür.
    nightService: ForegroundNightService(),
    sharer: PlatformSharer(),
    // Alarmın SESİ. Verilmezse alarm yalnızca ekranda görünür — uyuyan biri için
    // hiçbir işe yaramaz.
    alarmSound: SunriseAlarmSound(),
    // Süreç ölse bile son-tarihte uyandıran sistem backstop'u (EK güvence).
    // Native handler cihaz-kapılı; o gelene kadar en iyi çabayla sessizce atlanır.
    alarmScheduler: const PlatformNightAlarmScheduler(),
    // Çevrimdışı biten geceleri kaybetme (#177): secure storage'da kuyruğa alır,
    // açılışta + her başarılı kayıttan sonra sunucuya boşaltır.
    sessionQueue: SleepSessionQueue(SecureKeyValueStore()),
  );
});
