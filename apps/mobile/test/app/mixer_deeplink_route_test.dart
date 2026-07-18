import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// GERÇEK router'ı koşturur — `appRouter`'ın kendisini.
///
/// **BU DOSYANIN VARLIK SEBEBİ (mutasyon testiyle bulundu):** `router.dart`'taki
/// `state.uri.queryParameters['soundscape']` ifadesi `null` ile değiştirildiğinde
/// — yani "Bu sesi çal" HER ZAMAN varsayılan mikseri açar, özellik tamamen ölür —
/// 487 testin TAMAMI yine geçiyordu. Zincirin iki ucu testliydi (detay ekranı doğru
/// URL'i push ediyor; MixerRoute verilen slug'ın tarifiyle kuruluyor) ama ORTA
/// HALKA — URL'den slug'ın okunması — hiç koşturulmuyordu.
///
/// Buradaki testler gerçek `appRouter` üzerinden gider, dolayısıyla o satır
/// bozulursa KIRILIR.
void main() {
  SoundscapeDetail detail() => SoundscapeDetail(
        soundscape: Soundscape(
          id: 'ss-1',
          slug: 'deep-ocean-hush',
          titleI18n: const {'en': 'Deep Ocean Hush', 'tr': 'Derin Okyanus Sessizligi'},
          archetypeAffinity: const ['deep-ocean'],
          version: 1,
          mixSpec: MixSpec(const [
            MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.5),
            MixLayer(id: 'surf', type: LayerSource.pink, gain: 0.25),
          ]),
        ),
        presets: const [],
        previewUrl: null,
      );

  Future<void> pumpAt(WidgetTester tester, String location, {Object? resolved}) async {
    appRouter.go(location);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundscapeDetailProvider.overrideWith(
            (ref, slug) async => resolved as SoundscapeDetail?,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GERÇEK router: /mixer?soundscape=<slug> O SESİN tarifiyle açılır',
    (tester) async {
      await pumpAt(tester, '/mixer?soundscape=deep-ocean-hush', resolved: detail());

      // Sesin KENDİ katmanları ekranda; varsayılan tarifin katmanı YOK.
      // Bu iddia, slug URL'den okunmazsa (mutasyon) kırılır.
      expect(find.byKey(const Key('gain-deep')), findsOneWidget);
      expect(find.byKey(const Key('gain-surf')), findsOneWidget);
      expect(find.byKey(const Key('gain-brown')), findsNothing);
      // Tarif bulunduğu için "yüklenemedi" dipnotu OLMAMALI.
      expect(find.byKey(const Key('mixer-recipe-fallback')), findsNothing);
    },
  );

  testWidgets(
    'GERÇEK router: parametresiz /mixer varsayılan tarifle açılır',
    (tester) async {
      await pumpAt(tester, '/mixer', resolved: null);

      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      expect(find.byKey(const Key('gain-deep')), findsNothing);
    },
  );

  testWidgets(
    'GERÇEK router: bilinmeyen slug → varsayılan tarif + dürüst dipnot',
    (tester) async {
      await pumpAt(tester, '/mixer?soundscape=boyle-bir-ses-yok', resolved: null);

      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      // Kullanıcı seçtiği sesi DUYMUYOR — bunu söylemek zorundayız.
      expect(find.byKey(const Key('mixer-recipe-fallback')), findsOneWidget);
    },
  );
}
