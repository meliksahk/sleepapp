import 'package:flutter/widgets.dart';
import 'analytics.dart';

/// Uygulama arka plana geçince (paused/detached) analitik tamponunu gönderir.
/// WidgetsBinding'e observer olarak eklenir. Flush fire-and-forget — bloklamaz.
class AnalyticsFlusher with WidgetsBindingObserver {
  AnalyticsFlusher(this._analytics);

  final Analytics _analytics;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Sonucu beklenmez; hata analitiği düşürür, uygulamayı etkilemez.
      _analytics.flush();
    }
  }
}
