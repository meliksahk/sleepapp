import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
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
    recorder: SleepRecorder(mic: RecordMicSource()),
    sleep: ref.read(sleepControllerProvider),
  );
});
