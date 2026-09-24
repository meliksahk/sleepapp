import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/content/presentation/soundscape_library_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

import 'content_test_support.dart';

/// **Kütüphane EKRANI ağsız da dolu** — kullanıcının gerçekten gördüğü şey.
///
/// `content_library_test.dart` veri katmanını kilitliyor; bu dosya bir adım
/// öteye gidip EKRANI çiziyor. Ayrım önemli: veri doğru olup ekran yine hata
/// gösterebilir (sağlayıcı zinciri kopuksa). Kurulan APK'da yaşanan tam olarak
/// buydu — "Kütüphane" boştu.
void main() {
  setUp(() {
    // Ağ KAPALI flavor — prod APK'nın bugünkü hâli.
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.prod,
      name: 'PROD',
      apiBaseUrl: '',
    );
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          contentLibrarySourceProvider.overrideWithValue(testLibrarySource()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildNoctaDarkTheme(),
          home: const SoundscapeLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: ağ kapalıyken 7 soundscape listelenir (boş ekran YOK)',
      (tester) async {
    await pumpLibrary(tester);

    expect(
      find.byKey(const Key('soundscape-empty')),
      findsNothing,
      reason: 'kütüphane boş — gömülü içerik ekrana ulaşmıyor',
    );
    expect(
      find.byKey(const Key('soundscape-retry')),
      findsNothing,
      reason: 'hata durumu görünüyor — ağsız akış kırık',
    );

    // ListView tembel: son kartlar ekranın altında kalıyor olabilir. Kullanıcının
    // yaptığını yapıyoruz — kaydırıyoruz.
    for (final slug in <String>[
      'deep-ocean-hush',
      'rainfall-window',
      'delta-drift',
      'first-light',
      'night-train',
      'cabin-fan',
      LibraryFixture.demoSlug,
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key('soundscape-$slug')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(Key('soundscape-$slug')),
        findsOneWidget,
        reason: '"$slug" kartı kütüphanede yok',
      );
    }
  });

  testWidgets('"Hearth & Static" kullanıcıya GÖRÜNÜYOR', (tester) async {
    await pumpLibrary(tester);

    await tester.scrollUntilVisible(
      find.byKey(Key('soundscape-${LibraryFixture.demoSlug}')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(LibraryFixture.demoTitleEn), findsOneWidget);
    expect(
      find.byKey(Key('soundscape-affinity-${LibraryFixture.demoSlug}')),
      findsOneWidget,
      reason: 'affinity altyazısı seed\'den taşınmamış',
    );
  });

  testWidgets('kategori filtrelerinin HİÇBİRİ ağsız boş değil', (tester) async {
    // Regresyon: üretici seed'deki kategori UPDATE'lerini okumuyordu, gömülü
    // 25 tarifin hepsi 'nature' kalıyordu. "Relaxing" ve "Noise" kurulu APK'da
    // hep boştu. "Noise" ayrıca temiz kurulumda da boştu: kategori göçü boş
    // tabloya koşuyordu, atama seed'e taşındı.
    await pumpLibrary(tester);

    // Her filtrede listenin İLK kartı görünür olmalı; tembel liste yüzünden
    // yalnız en üstteki karta bakılıyor.
    for (final (chip, firstSlug, absentSlug) in <(String, String, String)>[
      ('Noise', 'delta-drift', 'deep-ocean-hush'),
      ('Relaxing', 'deep-hum', 'delta-drift'),
      ('Nature', 'deep-ocean-hush', 'delta-drift'),
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, chip));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('soundscape-empty')), findsNothing, reason: '"$chip" filtresi boş');
      expect(find.byKey(Key('soundscape-$firstSlug')), findsOneWidget, reason: '"$chip" filtresinde $firstSlug yok');
      expect(find.byKey(Key('soundscape-$absentSlug')), findsNothing, reason: '"$chip" filtresi $absentSlug gösteriyor');
    }
  });
}
