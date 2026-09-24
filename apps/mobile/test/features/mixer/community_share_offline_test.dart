import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/mixer/domain/local_sound.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:nocta/features/mixer/mixer_providers.dart';
import 'package:nocta/features/mixer/presentation/asset_catalog_sheet.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **Topluluğa paylaş düğmesi ağ KAPALIYKEN görünmez.**
///
/// Paylaşım bir sunucu çağrısıdır; kurulu APK'da ağ katmanı kapalı
/// (`apiBaseUrl: ''`). Düğme görünseydi kullanıcı başlık yazıp onaylar ve her
/// seferinde "birazdan tekrar dene" hatası alırdı: asla işlemeyecek bir akış.
void main() {
  final sound = LocalSound(
    id: 'local-0000000000000001',
    title: 'Mutfak',
    fileName: '0000000000000001__mutfak.m4a',
    sizeBytes: 2048,
    importedAt: DateTime.utc(2026),
  );

  Future<void> pump(WidgetTester t, String apiBaseUrl) async {
    FlavorConfig.current = FlavorConfig(
      flavor: apiBaseUrl.isEmpty ? Flavor.prod : Flavor.dev,
      name: apiBaseUrl.isEmpty ? 'PROD' : 'DEV',
      apiBaseUrl: apiBaseUrl,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localSoundLibraryProvider.overrideWithValue(
            InMemoryLocalSoundLibrary(sounds: <LocalSound>[sound]),
          ),
          audioAssetCatalogProvider.overrideWith(
            (ref) async => const <AudioAsset>[],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: AssetCatalogSheet(currentAssetLayerCount: 0),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: ağ KAPALIYKEN paylaş düğmesi YOK, ses listede', (t) async {
    await pump(t, '');

    expect(find.byKey(Key('local-sound-${sound.id}')), findsOneWidget);
    expect(find.byKey(Key('local-sound-share-${sound.id}')), findsNothing);
    // Silme ağ gerektirmez; o düğme yerinde kalır.
    expect(find.byKey(Key('local-sound-delete-${sound.id}')), findsOneWidget);
  });

  testWidgets('ağ AÇIKKEN paylaş düğmesi görünür', (t) async {
    await pump(t, 'http://localhost:3001');

    expect(find.byKey(Key('local-sound-share-${sound.id}')), findsOneWidget);
  });
}
