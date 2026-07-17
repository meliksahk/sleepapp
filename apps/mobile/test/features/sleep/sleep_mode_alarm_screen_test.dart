import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/presentation/sleep_mode_screen.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Akıllı alarmın EKRANI (docs/04 §86).
///
/// Mantık `sleep_mode_alarm_test.dart`'ta kanıtlandı; burada kanıtlanan: kullanıcı
/// alarma **ulaşabiliyor** ve çaldığında **ne yapacağını görüyor**. Alarm mantığı
/// dört iterasyon boyunca zaten doğruydu — ulaşılamadığı için değersizdi.
class _FakeSleep implements SleepController {
  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async => SleepSession(
        id: 's1',
        startedAt: draft.startedAt.toIso8601String(),
        endedAt: draft.endedAt.toIso8601String(),
        nightDate: '2026-07-17',
        durationMinutes: draft.duration.inMinutes,
        movementEvents: draft.movementEvents,
        soundEvents: draft.soundEvents,
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late SleepModeController controller;
  late DateTime clock;

  Future<void> pump(WidgetTester t) async {
    clock = DateTime(2026, 7, 17, 23);
    controller = SleepModeController(
      recorder: SleepRecorder(mic: FakeMicSource(<Float32List>[]), now: () => clock),
      sleep: _FakeSleep(),
      nightService: FakeNightService(),
      now: () => clock,
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: SleepModeScreen(controller: controller),
      ),
    );
  }

  testWidgets('ÇEKİRDEK: alarm varsayılan KAPALI (opt-in)', (t) async {
    await pump(t);
    // Varsayılan bir saat uydurmak, kullanıcıyı beklemediği anda uyandırmak olurdu.
    expect(find.text('Off'), findsOneWidget);
    expect(find.byKey(const Key('alarm-clear')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: ne yaptığını DÜRÜSTÇE anlatır (uyku evresi iddiası yok)',
      (t) async {
    await pump(t);
    final explain = t.widget<Text>(find.byKey(const Key('alarm-explain'))).data!;

    // Söylediğimiz: hafif bir AN arıyoruz + en geç o saatte uyandırıyoruz.
    expect(explain, contains('30 minutes'));
    expect(explain, contains('at the latest'));
    // Söylemediğimiz (CLAUDE.md §1.1): uyku evresi ölçtüğümüz.
    expect(explain.toLowerCase(), isNot(contains('rem')));
    expect(explain.toLowerCase(), isNot(contains('deep sleep')));
  });

  testWidgets('alarm kurulunca saat gösterilir ve "kapat" çıkar', (t) async {
    await pump(t);
    controller.setAlarm(DateTime(2026, 7, 18, 7, 30));
    await t.pump();

    expect(find.byKey(const Key('alarm-status')), findsOneWidget);
    expect(find.textContaining('7:30'), findsOneWidget);
    expect(find.byKey(const Key('alarm-clear')), findsOneWidget);
  });

  testWidgets('kapat → alarm kalkar', (t) async {
    await pump(t);
    controller.setAlarm(DateTime(2026, 7, 18, 7, 30));
    await t.pump();

    await t.tap(find.byKey(const Key('alarm-clear')));
    await t.pump();

    expect(find.text('Off'), findsOneWidget);
    expect(controller.state.alarmAt, isNull);
  });

  group('çalarken', () {
    testWidgets('ÇEKİRDEK: çalınca metin + SUSTUR düğmesi görünür', (t) async {
      await pump(t);
      controller.setAlarm(DateTime(2026, 7, 18, 7, 30));
      await controller.start(notificationTitle: 't', notificationBody: 'b');
      await t.pump();

      // Saati son tarihin ötesine al ve GERÇEK tick'in çalışmasını bekle.
      // Üretim koduna test arka kapısı açmak yerine zamanı ilerletiyoruz: böylece
      // test, kullanıcının yaşayacağı yolun aynısını yürür.
      clock = clock.add(const Duration(hours: 9));
      await t.pump(const Duration(seconds: 11)); // alarmTick = 10 sn
      await t.pump();

      expect(find.byKey(const Key('alarm-ringing')), findsOneWidget);
      // Son tarihte çaldı (hiç aktivite yoktu) → "vakit geldi" metni.
      expect(find.text('Time to wake up.'), findsOneWidget);
      expect(find.byKey(const Key('alarm-dismiss')), findsOneWidget);
    });

    testWidgets('ÇEKİRDEK: sustur → panel kapanır, GECE DEVAM EDER', (t) async {
      await pump(t);
      controller.setAlarm(DateTime(2026, 7, 18, 7, 30));
      await controller.start(notificationTitle: 't', notificationBody: 'b');
      clock = clock.add(const Duration(hours: 9));
      await t.pump(const Duration(seconds: 11));
      await t.pump();

      await t.tap(find.byKey(const Key('alarm-dismiss')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('alarm-ringing')), findsNothing);
      // Alarmı kapatmak geceyi bitirmez — kullanıcı uyumaya dönebilir.
      expect(controller.state.isRecording, isTrue);
    });
  });
}
