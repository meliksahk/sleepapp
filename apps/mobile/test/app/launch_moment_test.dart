import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/launch/launch_moment.dart';
import 'package:nocta/core/launch/launch_phase.dart';
import 'package:nocta/core/launch/moon_painter.dart';

/// Açılış anının **kullanıcıyı bekletmeme** sözleşmesi.
///
/// Bir splash animasyonunun tek gerçek riski vardır: uygulamayı yavaşlatmak.
/// Buradaki testler o riski dört yerden kapatır — üst sınır, erken hazır olma,
/// dokunuşla atlama, hareketi azalt.
/// Ayın faz kaynağını okur — "widget var mı" değil, "gerçekten ilerliyor mu"
/// sorusunu sorabilmek için.
ValueListenable<LaunchPhase> _phaseOf(WidgetTester t, Key moon) {
  final painter = t.widget<CustomPaint>(find.byKey(moon)).painter! as MoonPainter;
  return painter.phase;
}

void main() {
  const moon = Key('launch-moon');
  final home = find.text('ANA EKRAN');

  Widget wrap(Widget child, {MediaQueryData? mediaQuery}) {
    if (mediaQuery == null) return child;
    return MediaQuery(data: mediaQuery, child: child);
  }

  Widget gate({required bool ready, MediaQueryData? mediaQuery}) => wrap(
        LaunchMoment(
          ready: ready,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('ANA EKRAN'),
          ),
        ),
        mediaQuery: mediaQuery,
      );

  testWidgets('açılışta AY görünür, ana ekran HENÜZ değil', (t) async {
    await t.pumpWidget(gate(ready: false));
    await t.pump(const Duration(milliseconds: 300));

    expect(find.byKey(moon), findsOneWidget);
    expect(home, findsNothing);

    // Ay gerçekten ÇİZİLİYOR mu — sadece widget var mı değil. Zarf yükselirken
    // parlaklık artmalı; sabit kalırsa animasyon ölmüş demektir.
    final phase = _phaseOf(t, moon);
    final early = phase.value.glow;
    expect(early, greaterThan(0.0));
    await t.pump(const Duration(milliseconds: 250));
    expect(phase.value.glow, greaterThan(early),
        reason: 'ay canlanmıyor: faz ilerlemiyor');

    await t.pumpAndSettle();
  });

  testWidgets('ÇEKİRDEK: üst sınır dolunca içerik hazır OLMASA da geçilir', (t) async {
    await t.pumpWidget(gate(ready: false));

    // Üst sınırdan hemen ÖNCE hâlâ splash.
    await t.pump(Duration(milliseconds: (launchCapSeconds * 1000).round() - 100));
    expect(home, findsNothing);

    // Üst sınır + mikroanimasyon → uygulama açılmış olmalı. Oturum hiç
    // kurulmasa bile: "sonsuz splash" durumu yok.
    await t.pumpAndSettle();
    expect(home, findsOneWidget);
    expect(find.byKey(moon), findsNothing);
  });

  testWidgets('ÇEKİRDEK: erken hazırken geçiş alt sınırda başlar, üst sınırı beklemez',
      (t) async {
    await t.pumpWidget(gate(ready: true));

    // Alt sınırdan önce: hâlâ marka anı.
    await t.pump(Duration(milliseconds: (launchHoldSeconds * 1000).round() - 200));
    expect(home, findsNothing);

    // Alt sınır + mikroanimasyon: içeride.
    await t.pump(const Duration(milliseconds: 200));
    await t.pump(launchExitDuration);
    await t.pump(const Duration(milliseconds: 16));
    expect(home, findsOneWidget);

    // Ve bu, üst sınırdan ÖNCE oldu.
    final spent = launchHoldSeconds * 1000 + launchExitDuration.inMilliseconds + 16;
    expect(spent, lessThan(launchCapSeconds * 1000 + launchExitDuration.inMilliseconds));

    await t.pumpAndSettle();
  });

  testWidgets('ÇEKİRDEK: dokunuş açılışı ATLAR (alt sınır bile beklenmez)', (t) async {
    await t.pumpWidget(gate(ready: true));
    await t.pump(const Duration(milliseconds: 200));
    expect(home, findsNothing);

    await t.tap(find.byKey(const Key('launch-skip')));
    await t.pump();
    await t.pump(launchExitDuration);
    await t.pump(const Duration(milliseconds: 16));

    expect(home, findsOneWidget);
    expect(find.byKey(moon), findsNothing);
    await t.pumpAndSettle();
  });

  testWidgets('ÇEKİRDEK: hareketi azalt açıkken animasyon YOK, doğrudan ana ekran',
      (t) async {
    await t.pumpWidget(
      gate(ready: true, mediaQuery: const MediaQueryData(disableAnimations: true)),
    );
    await t.pump();

    // İLK karede içeride: ne bekleme, ne geçiş animasyonu.
    expect(home, findsOneWidget);
    expect(find.byKey(moon), findsNothing);
  });

  testWidgets('hareketi azalt + içerik hazır değil → durağan kare, animasyon yok',
      (t) async {
    await t.pumpWidget(
      gate(ready: false, mediaQuery: const MediaQueryData(disableAnimations: true)),
    );
    await t.pump();
    expect(find.byKey(moon), findsOneWidget);

    final phase = _phaseOf(t, moon);
    final first = phase.value.glow;
    // Siyah ekran DEĞİL: durağan ama görünür bir kare.
    expect(first, greaterThan(0.0));

    // Zaman ilerlese de kare DEĞİŞMEZ (kare üretimi yok).
    await t.pump(const Duration(seconds: 1));
    expect(phase.value.glow, first);
    expect(home, findsNothing);
  });

  testWidgets('hareketi azaltken içerik SONRADAN hazırlanırsa anında geçilir', (t) async {
    Widget build(bool ready) => gate(
          ready: ready,
          mediaQuery: const MediaQueryData(disableAnimations: true),
        );

    await t.pumpWidget(build(false));
    await t.pump();
    expect(home, findsNothing);

    await t.pumpWidget(build(true));
    await t.pump();
    expect(home, findsOneWidget);
  });

  testWidgets('geçiş bittiğinde onFinished bir kez çağrılır', (t) async {
    var finished = 0;
    await t.pumpWidget(
      LaunchMoment(
        ready: true,
        onFinished: () => finished++,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('ANA EKRAN'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets(
    'REGRESYON: hareketi-azalt + içerik HİÇ hazır olmasa da üst sınırda geçilir',
    (tester) async {
      // Denetimde ölçüldü: bu yolda ticker hiç çalışmadığı için üst sınır
      // DEĞERLENDİRİLMİYORDU — 10 saniye sonra hâlâ splash duruyordu. Sınıf notu
      // "sonsuz splash yapısal olarak imkânsız" diyordu; o iddia bu yol için
      // yanlıştı. Artık ticker'dan bağımsız bir zamanlayıcı sınırı uyguluyor.
      var finished = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LaunchMoment(
              ready: false,
              onFinished: () => finished = true,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('launch-moon')), findsOneWidget);

      // Üst sınırı geç.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pumpAndSettle();

      expect(
        finished,
        isTrue,
        reason: 'hareketi-azalt yolunda da üst sınır uygulanmalı',
      );
      expect(find.byKey(const Key('launch-moon')), findsNothing);
    },
  );
}
