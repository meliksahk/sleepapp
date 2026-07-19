import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **SON MİL:** kullanıcı katalogdan kendi dosyasını seçip mikse EKLEYEBİLİYOR mu.
///
/// Zincirin (tablo → uç → model → `AssetLayer` → `MixPlayer`) her halkası zaten
/// vardı ve test ediliyordu; eksik olan tek şey EKRANDI. Bu dosya o son halkayı
/// kilitler: katalog açılıyor, seçim katmana dönüşüyor, katman kaldırılabiliyor,
/// boş/hatalı durumlar kırılmıyor ve export'un bilinen deliği söyleniyor.
class _FakePlayer implements AudioPlayer {
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async =>
      Duration.zero;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const catalogAsset = AudioAsset(
    id: 'asset-42',
    title: 'Night Rain (own file)',
    genre: 'ambient',
    mood: <String>['calm', 'warm'],
    durationSeconds: 180,
    license: 'CC0',
    source: 'freesound.org/x',
  );

  const detail = AudioAssetDetail(
    asset: catalogAsset,
    url: 'https://minio.test/night-rain.mp3',
    expiresInSeconds: 900,
  );

  MixerController buildController([MixSpec? spec]) => MixerController(
        spec: spec ??
            const MixSpec(<MixLayer>[
              MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3),
            ]),
        player: MixPlayer(
          loopSeconds: 1,
          sampleRate: 8000,
          loopRenderer: (r) async => renderLoopSync(r),
          playerFactory: _FakePlayer.new,
        ),
      );

  /// [catalog] null → uç patlıyor (ağ yok / 401 / 404 gövdesi bozuk).
  Widget wrap(
    MixerController c, {
    List<AudioAsset>? catalog = const <AudioAsset>[catalogAsset],
    AudioAssetDetail? assetDetail = detail,
    bool detailThrows = false,
    bool canExportVideo = false,
  }) {
    return ProviderScope(
      overrides: <Override>[
        audioAssetCatalogProvider.overrideWith((ref) async {
          if (catalog == null) throw Exception('network down');
          return catalog;
        }),
        audioAssetDetailProvider.overrideWith((ref, id) async {
          if (detailThrows) throw Exception('401');
          return assetDetail;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MixerScreen(controller: c, canExportVideo: canExportVideo),
      ),
    );
  }

  Future<void> openCatalog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mixer-add-sound')));
    await tester.pumpAndSettle();
  }

  group('katalog', () {
    testWidgets('AÇILIYOR ve öğeleri listeliyor (ad + tür/mood)',
        (tester) async {
      await tester.pumpWidget(wrap(buildController()));
      await tester.pump();

      expect(find.byKey(const Key('mixer-add-sound')), findsOneWidget);
      await openCatalog(tester);

      expect(find.byKey(const Key('asset-catalog-title')), findsOneWidget);
      expect(
        find.byKey(const Key('asset-catalog-item-asset-42')),
        findsOneWidget,
      );
      expect(find.text('Night Rain (own file)'), findsOneWidget);
      // Tür ve mood etiketleri görünüyor (içerik değerleri, çevrilmez).
      expect(find.text('ambient · calm, warm'), findsOneWidget);
    });

    testWidgets('BOŞ katalog: ne yapılacağını söyleyen yönlendirme görünür',
        (tester) async {
      await tester.pumpWidget(
        wrap(buildController(), catalog: const <AudioAsset>[]),
      );
      await tester.pump();
      await openCatalog(tester);

      expect(find.byKey(const Key('asset-catalog-empty')), findsOneWidget);
      final how = tester.widget<Text>(
        find.byKey(const Key('asset-catalog-empty-how')),
      );
      // Dürüstlük: "hiç ses yok" demek yetmez — NEREYE koyacağını ve HANGİ
      // komutu çalıştıracağını söylemeli.
      expect(how.data, contains('assets-inbox'));
      expect(how.data, contains('.json'));
      expect(how.data, contains('assets:upload'));
    });

    testWidgets('AĞ HATASI: ekran KIRILMAZ — açıklama + yeniden dene',
        (tester) async {
      await tester.pumpWidget(wrap(buildController(), catalog: null));
      await tester.pump();
      await openCatalog(tester);

      // Sheet ayakta, hata durumu gösteriliyor, exception ekrana düşmedi.
      expect(find.byKey(const Key('asset-catalog-title')), findsOneWidget);
      expect(find.byKey(const Key('asset-catalog-retry')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Yeniden dene BASILABİLİR (yeniden istek atar; sonuç yine hata ama
      // ekran hâlâ ayakta — kullanıcı kapana kısılmadı).
      await tester.tap(find.byKey(const Key('asset-catalog-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-catalog-title')), findsOneWidget);
    });
  });

  group('mikse ekleme', () {
    testWidgets('seçilen ses KATMAN olarak eklenir ve SÜRGÜSÜ görünür',
        (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c));
      await tester.pump();
      await openCatalog(tester);

      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();

      // Durum: katman + kendi kazancı (AudioAssetDetail.toLayer varsayılanı 0.3).
      expect(c.state.assets.single.id, 'asset-42');
      expect(c.state.assets.single.url, 'https://minio.test/night-rain.mp3');
      expect(c.state.gains['asset-42'], 0.3);

      // Ekran: sürgü ve başlık gerçekten çizildi.
      expect(find.byKey(const Key('gain-asset-42')), findsOneWidget);
      expect(find.text('Night Rain (own file)'), findsOneWidget);
      // Sentez katmanı yerinde kaldı.
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      // Dosya katmanı geldiyse döngü dipnotu da gelir.
      expect(find.byKey(const Key('mixer-asset-loop-notice')), findsOneWidget);
    });

    testWidgets('eklenen katman KALDIRILABİLİR', (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c));
      await tester.pump();
      await openCatalog(tester);
      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gain-asset-42')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove-asset-42')));
      await tester.pumpAndSettle();

      expect(c.state.assets, isEmpty);
      expect(c.state.gains.containsKey('asset-42'), isFalse);
      expect(find.byKey(const Key('gain-asset-42')), findsNothing);
      // Dipnot da gitti: artık dosya katmanı yok.
      expect(find.byKey(const Key('mixer-asset-loop-notice')), findsNothing);
      // Sentez katmanına dokunulmadı.
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      // Kaldırma düğmesi YALNIZCA dosya katmanlarında: sentez katmanı tarifin
      // kendisidir, silinemez.
      expect(find.byKey(const Key('remove-brown')), findsNothing);
    });

    testWidgets('URL çözülemezse katman EKLENMEZ ve hata SÖYLENİR',
        (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c, detailThrows: true));
      await tester.pump();
      await openCatalog(tester);

      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();

      // Sessizce çalmayan bir sürgü bırakmak yasak.
      expect(c.state.assets, isEmpty);
      expect(find.byKey(const Key('gain-asset-42')), findsNothing);
      expect(c.state.errorKind, MixerErrorKind.assetAdd);
      expect(find.byKey(const Key('mixer-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kayıt SİLİNMİŞSE (404 → null) katman eklenmez', (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c, assetDetail: null));
      await tester.pump();
      await openCatalog(tester);
      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();

      expect(c.state.assets, isEmpty);
      expect(c.state.errorKind, MixerErrorKind.assetAdd);
    });
  });

  group('MixerController — katman ekleme/çıkarma', () {
    test('aynı id İKİ KEZ eklenemez (sürgü yanlış katmanı oynatırdı)', () async {
      final c = buildController();
      const layer = AssetLayer(id: 'a', title: 'A', url: 'u', gain: 0.3);
      expect(await c.addAsset(layer), isTrue);
      expect(await c.addAsset(layer), isFalse);
      expect(c.state.assets, hasLength(1));
    });

    test('prepare(), çalmadan ÖNCE eklenen katmanı da yükler', () async {
      final player = MixPlayer(
        loopSeconds: 1,
        sampleRate: 8000,
        loopRenderer: (r) async => renderLoopSync(r),
        playerFactory: _FakePlayer.new,
      );
      final c = MixerController(
        spec: const MixSpec(<MixLayer>[
          MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3),
        ]),
        player: player,
      );
      // Henüz prepare YOK → katman yalnızca state'e girer.
      await c.addAsset(
        const AssetLayer(id: 'a', title: 'A', url: 'file.wav', gain: 0.3),
      );
      expect(player.voiceCount, 0);

      await c.prepare();
      // Sentez + dosya: ikisi de yüklendi. `_spec` yüklenseydi dosya katmanı
      // sessizce dışarıda kalırdı.
      expect(player.voiceCount, 2);
    });

    test('hazır mikserde ekleme, player\'a CANLI katman ekler', () async {
      final player = MixPlayer(
        loopSeconds: 1,
        sampleRate: 8000,
        loopRenderer: (r) async => renderLoopSync(r),
        playerFactory: _FakePlayer.new,
      );
      final c = MixerController(
        spec: const MixSpec(<MixLayer>[
          MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3),
        ]),
        player: player,
      );
      await c.prepare();
      expect(player.voiceCount, 1);

      await c.addAsset(
        const AssetLayer(id: 'a', title: 'A', url: 'file.wav', gain: 0.3),
      );
      // Yeniden render YOK, yalnızca bir ses eklendi.
      expect(player.voiceCount, 2);

      await c.removeAsset('a');
      expect(player.voiceCount, 1);
    });
  });

  group('video export — bilinen delik SÖYLENİYOR', () {
    testWidgets('mikste dosya katmanı varken kalıcı dipnot görünür',
        (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c, canExportVideo: true));
      await tester.pump();
      expect(
        find.byKey(const Key('mixer-export-asset-warning')),
        findsNothing,
      );

      await openCatalog(tester);
      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mixer-export-asset-warning')),
        findsOneWidget,
      );
    });

    testWidgets('export\'a basınca ONAY çıkar; vazgeçilirse export BAŞLAMAZ',
        (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c, canExportVideo: true));
      await tester.pump();
      await openCatalog(tester);
      await tester.tap(find.byKey(const Key('asset-catalog-item-asset-42')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mixer-export-video')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mixer-export-warning-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mixer-export-warning-cancel')));
      await tester.pumpAndSettle();
      // Vazgeçti → hiçbir export başlamadı (ilerleme çubuğu yok).
      expect(c.state.isExporting, isFalse);
      expect(find.byKey(const Key('mixer-export-progress')), findsNothing);
    });

    testWidgets('uyarı EN DAR ekranda da düzeni taşırmaz (320×568)',
        (tester) async {
      // Uyarı, taşıma çubuğuna (SABİT yükseklik) konulsaydı 320×568'de bütçe
      // zaten dolu olduğu için çal butonunu ekran dışına iterdi. Kaydırılan
      // bölgeye konuldu — bu test o kararın bekçisi.
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final c = buildController(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3)],
        assets: <AssetLayer>[
          AssetLayer(id: 'a', title: 'A', url: 'u', gain: 0.3),
        ],
      ));
      await tester.pumpWidget(wrap(c, canExportVideo: true));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('mixer-export-asset-warning')),
        findsOneWidget,
      );
      // Birincil eylem hâlâ ekran içinde ve dokunulabilir (§7).
      final toggle = tester.getRect(find.byKey(const Key('mixer-toggle')));
      expect(toggle.bottom, lessThanOrEqualTo(568.0));
      expect(toggle.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('dosya katmanı YOKSA onay çıkmaz (gereksiz sürtünme üretme)',
        (tester) async {
      final c = buildController();
      await tester.pumpWidget(wrap(c, canExportVideo: true));
      await tester.pump();

      await tester.tap(find.byKey(const Key('mixer-export-video')));
      await tester.pump();

      expect(
        find.byKey(const Key('mixer-export-warning-dialog')),
        findsNothing,
      );
    });
  });
}
