import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import 'sleep_controller.dart';
import 'sleep_models.dart';

/// Uyku controller'ı — auth (oturum + refresh) + api client üzerine.
final sleepControllerProvider = Provider<SleepController>((ref) {
  return SleepController(ref.read(authControllerProvider), ref.read(apiClientProvider));
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
