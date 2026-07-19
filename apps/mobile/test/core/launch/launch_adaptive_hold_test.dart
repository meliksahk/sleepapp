import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/nocta_signature.dart';
import 'package:nocta/core/launch/launch_moment.dart';
import 'package:nocta/core/launch/launch_phase.dart';

/// **Uyarlanabilir alt sınır** — açılış anı ne kadar kısalabilir sözleşmesi.
///
/// Eski davranış ÖLÇÜLDÜ: içerik önbellekten anında hazır olsa bile her açılış
/// 1440 ms sürüyordu (1.1 sn alt sınır + 0.32 sn mikroanimasyon). Alt sınır
/// artık zarftan HESAPLANIYOR (ilk parıltının tepe anı) ve toplam düşüyor.
///
/// Buradaki testler süreyi ölçer AMA asıl koruduğu şey ters yön: sınır ne kadar
/// kısalırsa kısalsın ayın gerçekten GÖRÜLMÜŞ olması. "Bir kare titreme" hem
/// saatle (alt sınır) hem çizimle (`launchMinVisibleFrames`) yasaklanır.
void main() {
  final home = find.text('ANA EKRAN');
  const moon = Key('launch-moon');
  const step = Duration(milliseconds: 16); // ~60 fps

  Widget gate({required bool ready, VoidCallback? onFinished}) => LaunchMoment(
        ready: ready,
        onFinished: onFinished,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('ANA EKRAN'),
        ),
      );

  /// Açılışın BİTTİĞİ anı (onFinished) sanal saatte ölçer.
  Future<Duration?> measure(WidgetTester t, {required bool ready}) async {
    Duration? finishedAt;
    var elapsed = Duration.zero;
    await t.pumpWidget(gate(ready: ready, onFinished: () => finishedAt = elapsed));
    while (finishedAt == null && elapsed < const Duration(seconds: 6)) {
      elapsed += step;
      await t.pump(step);
    }
    return finishedAt;
  }

  test('alt sınır elle yazılmadı: zarftan hesaplanıyor', () {
    // Kaynak birliği: sabit kopyalansaydı ses değiştiği gün sınır yanlış yere
    // düşerdi. Tepe anı kapalı formda u* = a·ln(1 + d/a).
    expect(launchSparklePeakOffset, closeTo(0.1651, 1e-4));
    expect(launchHoldSeconds, closeTo(launchGrains.first.onset + 0.1651, 1e-4));
    expect(launchHoldSeconds, closeTo(0.8651, 1e-4));
  });

  test('yeni alt sınır marka jestini TAMAMLIYOR (zarf üstünde doğrulama)', () {
    // 1) Ay tam parlaklığa ulaşmış olmalı (zarfın tepesi geçilmiş).
    expect(launchHoldSeconds, greaterThan(signatureAttackSeconds));
    expect(
      signatureEnvelopeAt(launchHoldSeconds),
      closeTo(1.0, 1e-9),
      reason: 'alt sınırda zarf tepede değil: ay tam doğmamış',
    );

    // 2) İlk yıldız doğmuş VE tepe parlaklığında olmalı — "yanıp söndü" değil.
    final first = launchGrains.first;
    final atBound = launchPhaseAt(
      Duration(microseconds: (launchHoldSeconds * 1e6).round()),
    ).sparkles.first;
    expect(launchHoldSeconds, greaterThan(first.onset));
    // Tepe anının kendisi olduğu için çevresindeki her an DAHA SÖNÜK.
    double sparkleAt(double t) =>
        launchPhaseAt(Duration(microseconds: (t * 1e6).round())).sparkles.first;
    expect(atBound, greaterThan(sparkleAt(launchHoldSeconds - 0.05)));
    expect(atBound, greaterThan(sparkleAt(launchHoldSeconds + 0.05)));

    // 3) Ve hâlâ üst sınırın epey altında.
    expect(launchHoldSeconds, lessThan(launchCapSeconds));
  });

  testWidgets('ÖLÇÜM: içerik anında hazırken toplam süre yeni alt sınırda', (t) async {
    final total = await measure(t, ready: true);
    expect(total, isNotNull, reason: 'açılış hiç bitmedi');

    final floorMs =
        (launchHoldSeconds * 1000).ceil() + launchExitDuration.inMilliseconds;
    // Alt sınır + mikroanimasyondan ÖNCE bitemez...
    expect(total!.inMilliseconds, greaterThanOrEqualTo(floorMs));
    // ...ve iki kareden fazla gecikemez. İki, bir değil: geçiş denetleyicisi
    // tick içinde başlatıldığı için ilk tick'ini BİR SONRAKİ karede alır
    // (ölçüldü: 1216 ms = 880 alt sınır tick'i + 16 gecikme + 320 geçiş).
    expect(total.inMilliseconds, lessThanOrEqualTo(floorMs + 2 * step.inMilliseconds));

    // ÇEKİRDEK: eski ölçülen davranıştan (1440 ms) gerçekten kısa.
    expect(
      total.inMilliseconds,
      lessThan(1440),
      reason: 'açılış kısalmamış — görevin tek amacı buydu',
    );
    debugPrint('ÖLÇÜLEN TOPLAM (içerik hazır): ${total.inMilliseconds} ms '
        '(eski: 1440 ms · alt sınır ${(launchHoldSeconds * 1000).toStringAsFixed(1)} ms '
        '+ geçiş ${launchExitDuration.inMilliseconds} ms)');

    await t.pumpAndSettle();
  });

  testWidgets('ay yeni sınırda da GÖRÜLÜYOR: tek kare değil, onlarca kare', (t) async {
    await t.pumpWidget(gate(ready: true));

    // Ay ağaçtayken çizilen her kareyi say — "widget vardı" değil, "kare aktı".
    var moonFrames = 0;
    var elapsed = Duration.zero;
    while (find.byKey(moon).evaluate().isNotEmpty &&
        elapsed < const Duration(seconds: 3)) {
      moonFrames++;
      elapsed += step;
      await t.pump(step);
    }

    expect(moonFrames, greaterThanOrEqualTo(launchMinVisibleFrames));
    expect(
      moonFrames,
      greaterThan(30),
      reason: '60 fps\'te ay 0.5 sn\'den az görünmüş — titreme sınırına yakın',
    );
    debugPrint('AY EKRANDA ÇİZİLEN KARE: $moonFrames (~${moonFrames * 16} ms)');
  });

  testWidgets(
    'ÇEKİRDEK: saat dolsa da ay ÇİZİLMEDEN geçilmez (takılan soğuk açılış)',
    (t) async {
      await t.pumpWidget(gate(ready: true));
      // Tek dev kare: duvar saati alt sınırı AŞTI ama ay yalnızca bir kez
      // çizilmiş durumda. Yalnız saate bakan bir kapı burada geçerdi.
      await t.pump(const Duration(milliseconds: 1200));
      expect(
        home,
        findsNothing,
        reason: 'ay bir kez çizilmişken geçilmiş — tek kare titreme',
      );

      // Kareler akmaya başlayınca geçiş hemen olur.
      await t.pump(step);
      await t.pump(launchExitDuration);
      await t.pump(step);
      expect(home, findsOneWidget);
      await t.pumpAndSettle();
    },
  );

  testWidgets('KORUNDU: üst sınır hâlâ çalışıyor (içerik hiç hazır olmasa da)',
      (t) async {
    final total = await measure(t, ready: false);
    expect(total, isNotNull, reason: 'sonsuz splash');
    final capMs =
        (launchCapSeconds * 1000).ceil() + launchExitDuration.inMilliseconds;
    expect(total!.inMilliseconds, greaterThanOrEqualTo(capMs));
    expect(total.inMilliseconds, lessThanOrEqualTo(capMs + 2 * step.inMilliseconds));
    debugPrint('ÖLÇÜLEN TOPLAM (içerik hazır DEĞİL): ${total.inMilliseconds} ms');

    await t.pumpAndSettle();
  });

  testWidgets('KORUNDU: dokunuş alt sınırı da kare şartını da atlar', (t) async {
    await t.pumpWidget(gate(ready: true));
    await t.pump(const Duration(milliseconds: 100)); // alt sınırın ÇOK altında
    expect(home, findsNothing);

    await t.tap(find.byKey(const Key('launch-skip')));
    await t.pump();
    await t.pump(launchExitDuration);
    await t.pump(step);
    expect(home, findsOneWidget);
    expect(find.byKey(moon), findsNothing);
    await t.pumpAndSettle();
  });

  testWidgets('KORUNDU: hareketi-azalt yolu kare şartına TAKILMAZ', (t) async {
    // Bu yolda hiç kare üretilmiyor; kare şartı oraya sızsaydı açılış asılırdı.
    //
    // NOT (mevcut davranış, bu görevde DEĞİŞTİRİLMEDİ): bu kısa yolda `_finish`
    // çağrılmadığı için `onFinished` de tetiklenmez. Ölçüt bu yüzden geri çağrı
    // değil, ekranın kendisi.
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: LaunchMoment(
          ready: true,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('ANA EKRAN'),
          ),
        ),
      ),
    );
    await t.pump();
    expect(home, findsOneWidget);
    expect(find.byKey(moon), findsNothing);
  });
}
