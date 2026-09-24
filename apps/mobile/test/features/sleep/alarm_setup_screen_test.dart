import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/features/sleep/presentation/alarm_setup_screen.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Akıllı alarm kurulumu (F2).
///
/// **Neden kendi ekranı:** sistemin `showTimePicker`'ı yalnızca SAAT sorabiliyor.
/// Bu alarmın asıl ayarı ise pencere genişliği — "en geç 07:00, ama son N
/// dakikada hafif uykuda yakalarsan daha erken". Pencereyi soramayan bir kontrol
/// ürünün farkını gizliyordu.
/// Alarm ekranı uyku KAYDI yapmıyor; controller yalnızca alarm durumunu
/// tutuyor. Bu yüzden sleep bağımlılığı `noSuchMethod` ile boş geçiliyor.
class _NoopSleep implements SleepController {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  SleepModeController controller() => SleepModeController(
    recorder: SleepRecorder(mic: FakeMicSource(const [])),
    sleep: _NoopSleep(),
    nightService: FakeNightService(),
  );

  Future<void> pump(WidgetTester t, SleepModeController c) async {
    // Kök rota ŞART: ekran kaydettikten sonra `pop` ediyor; tek rotalı bir
    // router'da pop edilecek yer olmadığı için GoError atıyordu.
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (ctx, s) => const Scaffold(body: Text('kök')),
        ),
        GoRoute(
          path: '/alarm',
          builder: (ctx, s) => AlarmSetupScreen(controller: c),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        routerConfig: router,
      ),
    );
    await t.pumpAndSettle();
    router.push('/alarm');
    await t.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: pencere genişliği sürgüsü controller\'a YAZILIR', (
    t,
  ) async {
    final c = controller();
    c.setAlarm(DateTime.now().add(const Duration(hours: 8)));
    await pump(t, c);

    // Varsayılan 30 dk; sürgüyü sonuna sürükle → 60 dk.
    expect(c.alarmWindow, const Duration(minutes: 30));
    await t.drag(
      find.byKey(const Key('alarm-setup-window')),
      const Offset(500, 0),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('alarm-setup-save')));
    await t.pumpAndSettle();

    expect(
      c.alarmWindow,
      const Duration(minutes: 60),
      reason: 'ayar ekranda değişti ama controller eski pencereyle uyandıracak',
    );
  });

  testWidgets('saat SEÇİLMEDEN kaydet pasif (yarım alarm kurulmaz)', (t) async {
    final c = controller();
    await pump(t, c);
    final save = t.widget<NButton>(find.byKey(const Key('alarm-setup-save')));
    expect(save.onPressed, isNull);
  });

  testWidgets('temizle → alarm KALKAR', (t) async {
    final c = controller();
    c.setAlarm(DateTime.now().add(const Duration(hours: 8)));
    await pump(t, c);
    expect(c.state.alarmAt, isNotNull);

    await t.tap(find.byKey(const Key('alarm-setup-clear')));
    await t.pumpAndSettle();
    expect(c.state.alarmAt, isNull);
  });

  testWidgets('açıklama metni SAĞLIK İDDİASI taşımaz (CLAUDE.md §1.1)', (
    t,
  ) async {
    await pump(t, controller());
    final explain = t
        .widget<Text>(find.byKey(const Key('alarm-setup-explain')))
        .data!
        .toLowerCase();
    for (final banned in <String>['cure', 'treat', 'therapy', 'clinical']) {
      expect(explain.contains(banned), isFalse, reason: '"$banned" geçiyor');
    }
  });
}
