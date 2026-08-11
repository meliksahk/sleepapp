import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/mixer/domain/local_sound.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:nocta/features/mixer/mixer_providers.dart';
import 'package:nocta/features/mixer/presentation/asset_catalog_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **F1 — kategorili kütüphane + arama.**
///
/// Kilitlenen davranışlar:
///  1. Arama HER İKİ bölümü de süzer (cihazdaki dosyalar + NOCTA kütüphanesi).
///  2. Cihaz tarafı ANINDA süzülür (diskte); sunucu tarafı geciktirilir
///     (her tuşta istek atmamak için) — ikisi ayrı yollardan gider.
///  3. Kategori şeridi YALNIZCA kütüphaneyi süzer; cihazdaki sesler kaybolmaz.
///  4. Boş sonuç "katalog boş" DEĞİL "eşleşme yok" der.
void main() {
  const rain = AudioAsset(
    id: 'a-rain',
    title: 'Night Rain',
    genre: 'ambient',
    mood: <String>['calm'],
    durationSeconds: 120,
    license: 'CC0',
    source: 'test',
  );
  const hiss = AudioAsset(
    id: 'a-hiss',
    title: 'Tape Hiss',
    genre: 'noise',
    mood: <String>['focus'],
    durationSeconds: 60,
    license: 'CC0',
    source: 'test',
  );

  final localSounds = <LocalSound>[
    LocalSound(
      id: 'local-1',
      title: 'Yagmur kaydim',
      fileName: 'a.mp3',
      sizeBytes: 1024,
      importedAt: DateTime.utc(2026),
    ),
    LocalSound(
      id: 'local-2',
      title: 'Vapur',
      fileName: 'b.mp3',
      sizeBytes: 2048,
      importedAt: DateTime.utc(2026),
    ),
  ];

  Future<void> pump(WidgetTester tester) async {
    // Uzun tuval: tembel ListView'da ekran dışında kalan bir satır "bulunamadı"
    // diye okunur ve süzgeç testleri YANLIŞ sebeple yeşile döner.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // Sunucu davranışını taklit eder: q ve genre SUNUCUDA süzülür.
          audioAssetCatalogProvider.overrideWith((ref, query) async {
            const all = <AudioAsset>[rain, hiss];
            return <AudioAsset>[
              for (final a in all)
                if ((query.genre == null || a.genre == query.genre) &&
                    (query.search.isEmpty ||
                        RegExp(
                          RegExp.escape(query.search),
                          caseSensitive: false,
                        ).hasMatch(a.title)))
                  a,
            ];
          }),
          localSoundLibraryProvider.overrideWithValue(
            InMemoryLocalSoundLibrary(sounds: localSounds),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const AssetCatalogScreen(currentAssetLayerCount: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('açılışta iki bölüm de dolu (süzgeç yok)', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('local-sound-local-1')), findsOneWidget);
    expect(find.byKey(const Key('local-sound-local-2')), findsOneWidget);
    expect(find.byKey(const Key('asset-catalog-item-a-rain')), findsOneWidget);
    expect(find.byKey(const Key('asset-catalog-item-a-hiss')), findsOneWidget);
  });

  testWidgets('arama İKİ bölümü de süzer', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('asset-catalog-search')),
      'rain',
    );
    // Cihaz tarafı ANINDA: bir kare yeter, gecikme beklenmez.
    await tester.pump();
    expect(
      find.byKey(const Key('local-sound-local-2')),
      findsNothing,
      reason: 'cihazdaki eşleşmeyen ses anında düşmeliydi',
    );

    // Sunucu tarafı gecikmeli (her tuşta istek yok).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-catalog-item-a-rain')), findsOneWidget);
    expect(find.byKey(const Key('asset-catalog-item-a-hiss')), findsNothing);
  });

  testWidgets('arama harf duyarsız (BÜYÜK yazılan küçük başlığı bulur)', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('asset-catalog-search')),
      'VAPUR',
    );
    await tester.pump();

    expect(find.byKey(const Key('local-sound-local-2')), findsOneWidget);
    expect(find.byKey(const Key('local-sound-local-1')), findsNothing);
  });

  testWidgets('kategori şeridi YALNIZCA kütüphaneyi süzer', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('asset-catalog-genre-noise')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-catalog-item-a-hiss')), findsOneWidget);
    expect(find.byKey(const Key('asset-catalog-item-a-rain')), findsNothing);
    // ÇEKİRDEK: cihazdaki sesler kategoriye takılıp kaybolmaz — onların türü yok.
    expect(find.byKey(const Key('local-sound-local-1')), findsOneWidget);
    expect(find.byKey(const Key('local-sound-local-2')), findsOneWidget);
  });

  testWidgets('boş sonuç "katalog boş" demez, "eşleşme yok" der', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('asset-catalog-search')),
      'zzzz',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('local-no-matches')), findsOneWidget);
    expect(find.byKey(const Key('asset-catalog-no-matches')), findsOneWidget);
    // "Henüz sesin yok" mesajı YANLIŞ olurdu: kütüphane dolu, süzgeç boş.
    expect(find.byKey(const Key('asset-catalog-empty')), findsNothing);
  });
}
