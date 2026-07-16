import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/analytics/analytics.dart';
import 'package:nocta/features/analytics/analytics_flusher.dart';

class RecordingAnalytics implements Analytics {
  int flushCalls = 0;
  @override
  void track(String name, {Map<String, dynamic>? props}) {}
  @override
  Future<int> flush() async {
    flushCalls++;
    return 0;
  }
}

void main() {
  test('arka plana geçişte (paused/detached) flush eder', () {
    final a = RecordingAnalytics();
    final flusher = AnalyticsFlusher(a);

    flusher.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(a.flushCalls, 1);

    flusher.didChangeAppLifecycleState(AppLifecycleState.detached);
    expect(a.flushCalls, 2);
  });

  test('ön planda (resumed/inactive/hidden) flush ETMEZ', () {
    final a = RecordingAnalytics();
    final flusher = AnalyticsFlusher(a);

    flusher.didChangeAppLifecycleState(AppLifecycleState.resumed);
    flusher.didChangeAppLifecycleState(AppLifecycleState.inactive);
    flusher.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(a.flushCalls, 0);
  });
}
