import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/ambient/ambient_backdrop.dart';
import 'package:nocta/core/ambient/ambient_painter.dart';
import 'package:nocta/core/ambient/ambient_phase.dart';
import 'package:nocta/core/design_system/design_system.dart';

/// Testin zamanı: `Stopwatch` duvar saatidir ve `tester.pump(d)` onu ilerletmez.
/// Bu yüzden widget'a saat enjekte ediliyor — zaman deterministik.
class _FakeClock {
  Duration now = Duration.zero;
  Duration call() => now;
}

/// [steps] adım boyunca hem sahte saati hem test saatini [step] kadar ilerletir.
/// Her `pump` bir vsync karesi → ticker bir kez tetiklenir.
Future<void> _advance(
  WidgetTester tester,
  _FakeClock clock, {
  required Duration step,
  required int steps,
}) async {
  for (var i = 0; i < steps; i++) {
    clock.now += step;
    await tester.pump(step);
  }
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('kurulur ve AmbientPainter ile boyanır', (tester) async {
    final clock = _FakeClock();
    await tester.pumpWidget(_host(AmbientBackdrop(clock: clock.call)));

    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('ambient-backdrop')),
    );
    expect(paint.painter, isA<AmbientPainter>());
  });

  testWidgets('kimlik yoksa marka gradyanı, varsa arketip gradyanı kullanılır',
      (tester) async {
    final clock = _FakeClock();

    await tester.pumpWidget(_host(AmbientBackdrop(clock: clock.call)));
    var painter = tester
        .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
        .painter! as AmbientPainter;
    expect(painter.gradient, AmbientBackdrop.brandGradient);

    await tester.pumpWidget(
      _host(
        AmbientBackdrop(
          clock: clock.call,
          gradient: NoctaArchetypeGradient.deepOcean,
        ),
      ),
    );
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
        .painter! as AmbientPainter;
    expect(painter.gradient, NoctaArchetypeGradient.deepOcean);
  });

  testWidgets('kazanç değişince görsel parametre (drive) değişir', (tester) async {
    final clock = _FakeClock();

    AmbientDrive driveOf() => (tester
            .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
            .painter! as AmbientPainter)
        .drive;

    await tester.pumpWidget(
      _host(
        AmbientBackdrop(
          clock: clock.call,
          gains: const <String, double>{'waves': 0.10, 'pad': 0.05, 'brown': 0.85},
        ),
      ),
    );
    final calmDrive = driveOf();

    await tester.pumpWidget(
      _host(
        AmbientBackdrop(
          clock: clock.call,
          gains: const <String, double>{'waves': 0.70, 'pad': 0.20, 'brown': 0.10},
        ),
      ),
    );
    final livelyDrive = driveOf();

    debugPrint('ÖLÇÜM drive: sakin motion=${calmDrive.motion.toStringAsFixed(3)} '
        '→ canlı motion=${livelyDrive.motion.toStringAsFixed(3)}');
    expect(livelyDrive.motion, greaterThan(calmDrive.motion));
    expect(livelyDrive.glow, greaterThan(calmDrive.glow));
    expect(livelyDrive, isNot(calmDrive));
  });

  testWidgets('faz zamanla ilerler ve ses periyoduyla aynı (10 sn)', (tester) async {
    final clock = _FakeClock();
    await tester.pumpWidget(
      _host(AmbientBackdrop(clock: clock.call, framesPerSecond: 60)),
    );

    ValueListenable<AmbientPhase> phaseOf() => (tester
            .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
            .painter! as AmbientPainter)
        .phase;

    // t = 5 sn → kabarma TEPESİ (sesteki dalga da tam burada tepede).
    clock.now = const Duration(seconds: 5);
    await tester.pump(const Duration(milliseconds: 16));
    expect(phaseOf().value.swell, closeTo(1.0, 1e-9));

    // t = 10 sn → çukur. Bu, periyodun 10 sn olduğunun ÖLÇÜLMÜŞ kanıtı:
    // widget'ın canlı ürettiği değer, sesin zarfıyla aynı yerde.
    clock.now = const Duration(seconds: 10);
    await tester.pump(const Duration(milliseconds: 16));
    expect(phaseOf().value.swell, closeTo(0.0, 1e-9));

    clock.now = const Duration(seconds: 15);
    await tester.pump(const Duration(milliseconds: 16));
    expect(phaseOf().value.swell, closeTo(1.0, 1e-9));
  });

  group('PİL', () {
    testWidgets('kare hızı sınırlanıyor: 1 sn vsync\'te 12 fps ≈ 12 kare',
        (tester) async {
      final clock = _FakeClock();
      var frames = 0;
      await tester.pumpWidget(
        _host(
          AmbientBackdrop(
            clock: clock.call,
            framesPerSecond: 12,
            onFrame: (f) => frames = f,
          ),
        ),
      );

      // 60 Hz vsync: 1 saniyede 60 tick.
      await _advance(tester, clock,
          step: const Duration(milliseconds: 16), steps: 60);

      debugPrint('ÖLÇÜM kare hızı: 60 vsync tick → $frames boyanan kare (hedef 12)');
      // Kova aritmetiği yüzünden ±1 sapabilir; asıl iddia "60 değil, ~12".
      expect(frames, inInclusiveRange(11, 13));
    });

    testWidgets('uygulama arka plana geçince kare ÜRETİLMEZ', (tester) async {
      final clock = _FakeClock();
      var frames = 0;
      await tester.pumpWidget(
        _host(
          AmbientBackdrop(
            clock: clock.call,
            framesPerSecond: 12,
            onFrame: (f) => frames = f,
          ),
        ),
      );

      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 5);
      final beforePause = frames;
      expect(beforePause, greaterThan(0), reason: 'önce çalışıyor olmalı');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 20);
      debugPrint('ÖLÇÜM arka plan: duraklamadan önce $beforePause kare, '
          '2 sn arka planda $frames kare');
      expect(frames, beforePause, reason: 'arka planda tek kare bile üretilmemeli');

      // Geri dönünce kare üretimi devam eder. Faz ise arka planda GEÇEN süreyi
      // atlamaz: saat de donmuştu (parlaklık sıçraması — `ambient_resume_test.dart`).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 5);
      expect(frames, greaterThan(beforePause));
    });

    testWidgets('inactive/hidden durumları da tick\'i durdurur', (tester) async {
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        final clock = _FakeClock();
        var frames = 0;
        await tester.pumpWidget(
          _host(
            AmbientBackdrop(
              key: ValueKey<AppLifecycleState>(state),
              clock: clock.call,
              framesPerSecond: 12,
              onFrame: (f) => frames = f,
            ),
          ),
        );
        await _advance(tester, clock,
            step: const Duration(milliseconds: 100), steps: 3);
        final before = frames;

        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        await _advance(tester, clock,
            step: const Duration(milliseconds: 100), steps: 10);
        expect(frames, before, reason: '$state durumunda kare üretilmemeli');

        // Sonraki tur için temiz durum.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
      }
    });

    testWidgets('ekranda görünmezken (TickerMode kapalı) kare ÜRETİLMEZ',
        (tester) async {
      final clock = _FakeClock();
      var frames = 0;
      await tester.pumpWidget(
        _host(
          TickerMode(
            enabled: false,
            child: AmbientBackdrop(
              clock: clock.call,
              framesPerSecond: 12,
              onFrame: (f) => frames = f,
            ),
          ),
        ),
      );

      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 20);
      debugPrint('ÖLÇÜM TickerMode kapalı: 2 sn → $frames kare');
      expect(frames, 0);
    });

    testWidgets('"hareketi azalt" açıkken hiç kare üretilmez (erişilebilirlik)',
        (tester) async {
      final clock = _FakeClock();
      var frames = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AmbientBackdrop(
              clock: clock.call,
              framesPerSecond: 12,
              onFrame: (f) => frames = f,
            ),
          ),
        ),
      );

      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 20);
      expect(frames, 0);

      // Durağan ama ölü değil: sabit bir kare gösterilir.
      final phase = (tester
              .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
              .painter! as AmbientPainter)
          .phase;
      expect(phase.value.swell, greaterThan(0));
    });

    testWidgets('dispose sonrası tick kalmaz (sızıntı yok)', (tester) async {
      final clock = _FakeClock();
      var frames = 0;
      await tester.pumpWidget(
        _host(
          AmbientBackdrop(
            clock: clock.call,
            onFrame: (f) => frames = f,
          ),
        ),
      );
      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 3);
      final before = frames;

      await tester.pumpWidget(_host(const SizedBox()));
      await _advance(tester, clock,
          step: const Duration(milliseconds: 100), steps: 10);
      expect(frames, before);
    });
  });
}
