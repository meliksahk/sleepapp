import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/media/card_renderer.dart';
import 'package:nocta/features/sleep/presentation/night_report_card.dart';

/// Gece raporu kartı — **viral kanca #2** (docs/04 §119).
///
/// Kimlik kartıyla (#140) aynı dürüstlük sınırı: golden'lar test fontuyla render
/// oluyor → **geometriyi** sabitliyorlar, tipografiyi değil. Render süresi de burada
/// ölçülmez (`toImage` headless ortamda asılı kalıyor) — cihazda ölçülür.
void main() {
  const labels = NightReportCardLabels(
    header: 'Night receipt',
    duration: '7h 12m',
    calmLabel: 'Calm',
    loudLabel: 'Louder moments',
    streakLabel: 'Night streak',
    identityLabel: 'Identity',
    disclaimer: 'An in-app calm measure for your sleep ritual. Not a health score.',
  );

  Future<void> pumpCard(
    WidgetTester t, {
    int soundEvents = 4,
    int calmScore = 78,
    int streak = 3,
    String? archetypeName = 'Deep Ocean',
    double textScale = 1.0,
  }) async {
    t.view.physicalSize = shareCardSize;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: NightReportCard(
          nightDate: '2026-07-17',
          durationMinutes: 432,
          soundEvents: soundEvents,
          calmScore: calmScore,
          streak: streak,
          archetypeName: archetypeName,
          gradient: NoctaArchetypeGradient.overthinker,
          labels: labels,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  group('dürüstlük — kart bir iddia taşımamalı', () {
    testWidgets('ÇEKİRDEK: sağlık iddiası UYARISI kartın ÜSTÜNDE', (t) async {
      await pumpCard(t);

      // Kart PAYLAŞILIYOR: uyarı uygulamanın içinde kalırsa kartı gören kişi
      // "Calm 78/100"u bir sağlık skoru sanar (CLAUDE.md §1.1).
      expect(find.byKey(const Key('report-card-disclaimer')), findsOneWidget);
      expect(find.textContaining('Not a health score'), findsOneWidget);
    });

    testWidgets('ÇEKİRDEK: "hareket" satırı YOK — ölçmediğimizi göstermiyoruz', (t) async {
      await pumpCard(t);

      // `movementEvents` her zaman 0 (ölçmüyoruz, docs/04 §120 fixture'ları yok).
      // "Movement: 0" göstermek, ölçmediğimiz bir şeyi ölçmüş gibi sunmaktır —
      // sıfır bile bir iddiadır (DECISIONS D-10).
      expect(find.textContaining('Movement'), findsNothing);
      expect(find.text('Louder moments'), findsOneWidget);
    });

    testWidgets('marka izi var (viral döngü kapansın)', (t) async {
      await pumpCard(t);
      expect(find.byKey(const Key('report-card-wordmark')), findsOneWidget);
    });
  });

  group('içerik', () {
    testWidgets('süre, dinginlik ve yüksek anlar kartta', (t) async {
      await pumpCard(t);

      expect(find.byKey(const Key('report-card-duration')), findsOneWidget);
      expect(find.text('7h 12m'), findsOneWidget);
      expect(find.text('78/100'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('seri YOKSA o satır hiç çizilmez (0 gösterilmez)', (t) async {
      await pumpCard(t, streak: 0);
      expect(find.byKey(const Key('report-card-streak')), findsNothing);
      expect(find.text('Night streak'), findsNothing);
    });

    testWidgets('kimlik yoksa o satır çizilmez (kart yine çalışır)', (t) async {
      await pumpCard(t, archetypeName: null);
      expect(find.text('Identity'), findsNothing);
      expect(find.byKey(const Key('report-card-duration')), findsOneWidget);
    });

    testWidgets('sessiz gece (0 olay) kartı BOZMAZ', (t) async {
      await pumpCard(t, soundEvents: 0);
      expect(find.byKey(const Key('report-card-loud')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('paylaşılan artefakt kararlı', () {
    testWidgets('ÇEKİRDEK: sistem yazı boyutu 3× olsa da kart BOZULMAZ', (t) async {
      await pumpCard(t, textScale: 3.0);
      expect(t.takeException(), isNull, reason: 'taşma olmamalı');
    });

    testWidgets('uzun kimlik adı kartı taşırmaz', (t) async {
      await pumpCard(t, archetypeName: 'The Extremely Overthinking Ruminator');
      expect(t.takeException(), isNull);
    });
  });

  group('golden — tasarım kazara değişmesin', () {
    testWidgets('gece makbuzu 1080×1920 piksel piksel sabit', (t) async {
      await pumpCard(t);
      await expectLater(
        find.byType(NightReportCard),
        matchesGoldenFile('goldens/night_report_card.png'),
      );
    });
  });
}
