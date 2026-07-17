import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/media/card_renderer.dart';
import 'package:nocta/features/archetype/presentation/identity_share_card.dart';

/// Paylaşım kartı — **viral kanca #1**, cihazsız doğrulanıyor.
///
/// ## Neyi kanıtlıyor, neyi kanıtlayamıyor (dürüstlük)
///
/// **Kanıtlıyor:** kart 1080×1920 olarak GERÇEKTEN çiziliyor; içerik doğru; sistem
/// yazı boyutu bozmuyor; her archetype kendi gradyanını alıyor. Golden dosyası
/// piksel piksel sabitlenmiş — tasarım kazara değişirse test kırılır.
///
/// **Kanıtlayamıyor:** `renderWidgetToPng`'nin çalışması ve **300ms bütçesi**.
/// Denedim: `toImage()` bu headless ortamda ASILI KALIYOR (`runAsync` ile bile) —
/// `matchesGoldenFile` farklı bir yakalama yolu kullanıyor, `toImage` motorun GPU
/// yüzeyini istiyor. O yüzden render süresi EMÜLATÖRDE ölçüldü, burada değil.
/// Bunu saklamak, geçen bir testi kanıt diye sunmak olurdu.
void main() {
  Future<void> pumpCard(
    WidgetTester t, {
    String name = 'Deep Ocean',
    String? tagline = 'You sink fast and stay under.',
    String slug = 'deep-ocean',
    double textScale = 1.0,
  }) async {
    t.view.physicalSize = shareCardSize;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: IdentityShareCard(
          name: name,
          tagline: tagline,
          gradient: IdentityShareCard.gradientFor(slug),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  group('içerik', () {
    testWidgets('isim, tagline ve MARKA İZİ kartta', (t) async {
      await pumpCard(t);

      expect(find.byKey(const Key('share-card-name')), findsOneWidget);
      expect(find.byKey(const Key('share-card-tagline')), findsOneWidget);
      // Marka izi olmadan paylaşılan kart viral döngüyü KAPATMAZ — kimse
      // uygulamanın adını bilmez.
      expect(find.byKey(const Key('share-card-wordmark')), findsOneWidget);
    });

    testWidgets('tagline yoksa kart yine çizilir (çökmez)', (t) async {
      await pumpCard(t, tagline: null);
      expect(find.byKey(const Key('share-card-name')), findsOneWidget);
      expect(find.byKey(const Key('share-card-tagline')), findsNothing);
    });

    testWidgets('bilinmeyen archetype slug\'ı ÇÖKMEZ, jeneriğe düşer', (t) async {
      await pumpCard(t, slug: 'boyle-bir-archetype-yok');
      expect(find.byKey(const Key('share-card-name')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('her archetype\'ın KENDİ gradyanı var', () {
      final firsts = {
        IdentityShareCard.gradientFor('deep-ocean').colors.first,
        IdentityShareCard.gradientFor('overthinker').colors.first,
        IdentityShareCard.gradientFor('delta-drifter').colors.first,
        IdentityShareCard.gradientFor('dawn-chaser').colors.first,
      };
      // İki archetype aynı gradyanı paylaşırsa kartın anlamı kalmaz.
      expect(firsts.length, 4);
    });
  });

  group('paylaşılan artefakt kararlı', () {
    testWidgets('ÇEKİRDEK: sistem yazı boyutu 3× olsa da kart BOZULMAZ', (t) async {
      // Erişilebilirlik ayarı EKRAN içindir; paylaşılan görsel her cihazda AYNI
      // görünmeli. Kart kendi MediaQuery'sini dayatıyor.
      await pumpCard(t, textScale: 3.0);
      expect(t.takeException(), isNull, reason: 'taşma olmamalı');
    });

    testWidgets('uzun isim/tagline kartı taşırmaz', (t) async {
      await pumpCard(
        t,
        name: 'The Extremely Overthinking Midnight Ruminator',
        tagline: 'Your mind replays the whole day, every night, in high definition, '
            'and then asks for an encore.',
      );
      expect(t.takeException(), isNull);
    });
  });

  group('golden — tasarım kazara değişmesin', () {
    testWidgets('deep-ocean kartı 1080×1920 piksel piksel sabit', (t) async {
      await pumpCard(t);
      await expectLater(
        find.byType(IdentityShareCard),
        matchesGoldenFile('goldens/identity_card_deep_ocean.png'),
      );
    });

    testWidgets('dawn-chaser kartı (farklı gradyan gerçekten uygulanıyor)', (t) async {
      await pumpCard(t, name: 'Dawn Chaser', tagline: 'You wake with the sun.', slug: 'dawn-chaser');
      await expectLater(
        find.byType(IdentityShareCard),
        matchesGoldenFile('goldens/identity_card_dawn_chaser.png'),
      );
    });
  });
}
