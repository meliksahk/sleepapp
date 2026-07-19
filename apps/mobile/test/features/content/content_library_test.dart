import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/features/content/content_controller.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_service.dart';
import 'package:nocta/features/content/data/content_library_source.dart';

import 'content_test_support.dart';

/// **Kütüphane BACKEND OLMADAN dolu** — gömülü içeriğin sözleşmesi.
///
/// ## Neden bu test var
///
/// `content_controller.dart`'taki üç uç da KOŞULSUZ ağa gidiyordu ve yerel yedek
/// yoktu. `api.nocta.app` ayakta olmadığı için kurulan prod APK'da kütüphane
/// BOŞTU — kullanıcı "Kütüphane"ye giriyor, hata ekranı görüyordu. CLAUDE.md
/// §3.1 "offline-first" bunu yasaklıyor.
///
/// Testler diskteki GERÇEK üretilmiş asset'i okur (uydurma örnek değil): asset
/// yolu bozulursa, codegen bozulursa ya da seed'den bir tarif düşerse burada
/// patlar.
void main() {
  group('gömülü kütüphane (assets/content/library.json)', () {
    test('asset gerçekten var ve pubspec.yaml\'da bildirilmiş', () {
      expect(
        File(contentLibraryAsset).existsSync(),
        isTrue,
        reason: '$contentLibraryAsset yok — pnpm gen:content koştu mu?',
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains(contentLibraryAsset),
        reason: 'asset pubspec.yaml\'da bildirilmemişse APK\'ya GİRMEZ.',
      );
    });

    test('seed\'deki yayınlanmış tariflerin TAMAMI gömülü', () async {
      final library = await testLibrarySource().load();

      expect(library.details, hasLength(LibraryFixture.soundscapeCount));
      expect(
        library.soundscapes.map((s) => s.slug),
        containsAll(<String>[
          'deep-ocean-hush',
          'rainfall-window',
          'delta-drift',
          'first-light',
          'night-train',
          'cabin-fan',
          LibraryFixture.demoSlug,
        ]),
      );
    });

    /// #215'in demo tarifi (müzik + gürültü + efekt) YALNIZCA seed.sql'de
    /// yaşıyordu: motorun pad/fire yeteneği kurulan APK'da HİÇ görünmüyordu.
    test('"Hearth & Static" görünüyor ve pad+white+fire katmanlarını taşıyor',
        () async {
      final library = await testLibrarySource().load();
      final detail = library.detail(LibraryFixture.demoSlug);

      expect(detail, isNotNull, reason: 'demo tarif gömülü kütüphanede yok');
      expect(detail!.soundscape.title('en'), LibraryFixture.demoTitleEn);
      expect(detail.soundscape.title('tr'), 'Ocak ve Parazit');

      final spec = detail.soundscape.mixSpec;
      expect(spec, isNotNull, reason: 'tarif ayrıştırılamıyor → cihazda SES GELMEZ');
      expect(
        spec!.layers.map((l) => l.type),
        containsAll(<LayerSource>[LayerSource.pad, LayerSource.white, LayerSource.fire]),
      );
    });

    test('her tarif motor sözleşmesine göre ÇALINABİLİR (hiçbiri null değil)',
        () async {
      final library = await testLibrarySource().load();
      for (final s in library.soundscapes) {
        expect(
          s.mixSpec,
          isNotNull,
          reason: '"${s.slug}" tarifi ayrıştırılamıyor → kullanıcı sesi açar, ses gelmez',
        );
      }
    });

    test('preset\'ler doğru soundscape\'e bağlı ve ayrıştırılabilir', () async {
      final library = await testLibrarySource().load();
      final nightTrain = library.detail('night-train');

      expect(nightTrain, isNotNull);
      expect(
        nightTrain!.presets.map((p) => p.archetypeSlug),
        containsAll(<String>['delta-drifter', 'overthinker']),
      );
      for (final preset in nightTrain.presets) {
        expect(
          preset.mixerState,
          isNotNull,
          reason: '"${preset.archetypeSlug}" preset\'i ayrıştırılamıyor',
        );
      }
    });

    /// `week_start` asset'te DONDURULMUŞ bir tarih değil, okuma anında uygulanan
    /// bir kural ("içinde bulunulan haftanın pazartesisi"). Dondurulsaydı APK'daki
    /// yayın kurulumdan haftalar sonra "geçmiş hafta" görünürdü.
    test('haftalık yayın, okuma anındaki haftanın PAZARTESİsini taşır', () async {
      // 2026-07-19 bir PAZAR; o haftanın pazartesisi 2026-07-13.
      final library = await testLibrarySource(
        now: () => DateTime(2026, 7, 19, 3),
      ).load();

      expect(library.weekly, isNotNull);
      expect(library.weekly!.weekStart, '2026-07-13');
      expect(library.weekly!.soundscapes, hasLength(LibraryFixture.weeklyCount));

      // Pazartesinin KENDİSİ de o haftaya aittir (kenar durum).
      final onMonday = await testLibrarySource(
        now: () => DateTime(2026, 7, 13, 23, 59),
      ).load();
      expect(onMonday.weekly!.weekStart, '2026-07-13');
    });

    test('bozuk/eksik asset SESSİZCE değil, bağlamlı bir hatayla patlar', () async {
      expect(
        () => brokenLibrarySource().load(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(contentLibraryAsset),
          ),
        ),
      );
    });
  });

  group('ContentService — yerel-öncelikli birleştirme politikası', () {
    test('sunucu YOKKEN (remote null) kütüphane gömülü içerikle dolu', () async {
      final service = ContentService(library: testLibrarySource());

      final feed = await service.feed();
      expect(feed, hasLength(LibraryFixture.soundscapeCount));
      expect(feed.map((s) => s.slug), contains(LibraryFixture.demoSlug));

      expect((await service.soundscape('night-train'))?.presets, isNotEmpty);
      expect((await service.weekly())?.soundscapes, hasLength(LibraryFixture.weeklyCount));
    });

    test('sunucu PATLARSA kullanıcı hata görmez, gömülü içerik döner', () async {
      final service = ContentService(
        library: testLibrarySource(),
        remote: _ThrowingContent(),
      );

      final feed = await service.feed();
      expect(feed, hasLength(LibraryFixture.soundscapeCount));
      expect(await service.soundscape('cabin-fan'), isNotNull);
      expect(await service.weekly(), isNotNull);
    });

    /// KARAR: içerik mağaza sürümü beklemeden güncellenebilmeli (CMS'in varlık
    /// sebebi). Sunucu konuşuyorsa o kazanır.
    test('sunucu YANIT VERİRSE sunucu kazanır (içerik güncellenebilir)', () async {
      final service = ContentService(
        library: testLibrarySource(),
        remote: _StubContent(feedResult: <Soundscape>[_soundscape('brand-new')]),
      );

      final feed = await service.feed();
      expect(feed.map((s) => s.slug), <String>['brand-new']);
    });

    /// TEK İSTİSNA: boş yanıt kazanmaz. Seed'lenmemiş/yanlış yapılandırılmış bir
    /// sunucu, kullanıcının kütüphanesini sessizce SİLERDİ — ağ hatasından beter,
    /// çünkü hata gibi görünmez.
    test('sunucu BOŞ liste dönerse gömülü kütüphane korunur', () async {
      final service = ContentService(
        library: testLibrarySource(),
        remote: _StubContent(feedResult: const <Soundscape>[]),
      );

      final feed = await service.feed();
      expect(feed, hasLength(LibraryFixture.soundscapeCount));
    });

    test('hiçbir kaynakta olmayan slug → null (çökme değil)', () async {
      final service = ContentService(library: testLibrarySource());
      expect(await service.soundscape('yok-boyle-bir-ses'), isNull);
    });
  });
}

Soundscape _soundscape(String slug) => Soundscape(
      id: slug,
      slug: slug,
      titleI18n: <String, String>{'en': slug},
      archetypeAffinity: const <String>[],
      version: 1,
      mixSpec: const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.pink, gain: 0.5),
      ]),
    );

/// Her çağrısı patlayan sunucu — "ağ öldü" hâli.
class _ThrowingContent implements ContentController {
  @override
  Future<List<Soundscape>> feed({String? archetype}) async =>
      throw StateError('ağ yok');

  @override
  Future<SoundscapeDetail?> soundscape(String slug) async =>
      throw StateError('ağ yok');

  @override
  Future<WeeklyRelease?> weekly() async => throw StateError('ağ yok');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sabit yanıt dönen sunucu.
class _StubContent implements ContentController {
  _StubContent({required this.feedResult});

  final List<Soundscape> feedResult;

  @override
  Future<List<Soundscape>> feed({String? archetype}) async => feedResult;

  @override
  Future<SoundscapeDetail?> soundscape(String slug) async => null;

  @override
  Future<WeeklyRelease?> weekly() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
