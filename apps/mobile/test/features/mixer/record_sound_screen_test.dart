import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/asset_layer.dart';
import 'package:nocta/features/mixer/domain/local_sound.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:nocta/features/mixer/domain/sound_recorder.dart';
import 'package:nocta/features/mixer/mixer_providers.dart';
import 'package:nocta/features/mixer/presentation/record_sound_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **F3 — kendi kaydın.** Kilitlenen davranışlar:
///  1. İzin verilmezse kayıt BAŞLAMAZ ve kullanıcı sebebini görür.
///  2. Kayıt → durdur → mekân etiketi → kütüphane → mikse katman.
///  3. Vazgeçme yarım dosya bırakmaz (recorder.cancel çağrılır).
///  4. Ekranda PAYLAŞ yok ve gizlilik sözü görünür (UGC ertelendi).
class _FakeRecorder implements SoundRecorder {
  _FakeRecorder({this.permitted = true});

  bool permitted;
  bool started = false;
  bool cancelled = false;
  bool stopped = false;
  String? startedPath;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<void> start(String path) async {
    started = true;
    startedPath = path;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return startedPath;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeRecorder recorder;
  late InMemoryLocalSoundLibrary library;

  Future<void> pump(
    WidgetTester tester, {
    bool permitted = true,
    LocalSoundImportResult? adoptResult,
    int layers = 0,
    void Function(AssetLayer)? onResult,
  }) async {
    recorder = _FakeRecorder(permitted: permitted);
    library = InMemoryLocalSoundLibrary()..adoptResult = adoptResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          soundRecorderProvider.overrideWithValue(recorder),
          localSoundLibraryProvider.overrideWithValue(library),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final layer = await Navigator.of(context).push<AssetLayer>(
                      MaterialPageRoute<AssetLayer>(
                        builder: (_) =>
                            RecordSoundScreen(currentAssetLayerCount: layers),
                      ),
                    );
                    if (layer != null) onResult?.call(layer);
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('gizlilik sözü ekranda, PAYLAŞ düğmesi YOK (UGC ertelendi)', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byKey(const Key('record-privacy')), findsOneWidget);
    expect(find.textContaining('not shared'), findsOneWidget);
    expect(find.textContaining('Share'), findsNothing);
  });

  testWidgets('ÇEKİRDEK: izin YOKSA kayıt başlamaz, sebep söylenir', (
    tester,
  ) async {
    await pump(tester, permitted: false);

    await tester.tap(find.byKey(const Key('record-start')));
    await tester.pumpAndSettle();

    expect(recorder.started, isFalse);
    expect(find.byKey(const Key('record-error')), findsOneWidget);
    expect(find.byKey(const Key('record-stop')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: kaydet → durdur → adlandır → mikse katman', (
    tester,
  ) async {
    AssetLayer? received;
    await pump(tester, onResult: (l) => received = l);

    await tester.tap(find.byKey(const Key('record-start')));
    await tester.pumpAndSettle();
    expect(recorder.started, isTrue);
    expect(recorder.startedPath, endsWith('.part'), reason: 'yarım kayıt gizli kalmalı');

    // Sayaç ilerliyor.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-stop')));
    await tester.pumpAndSettle();
    expect(recorder.stopped, isTrue);

    await tester.enterText(
      find.byKey(const Key('record-title')),
      'Mutfak, yağmur',
    );
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(library.adoptCallCount, 1);
    expect(received, isNotNull, reason: 'kayıt mikse katman olarak dönmeli');
    expect(received!.title, 'Mutfak, yağmur');
    // Yeni katman DÜŞÜK kazançla gelir: gece yarısı ani seviye sıçraması olmasın.
    expect(received!.gain, 0.3);
  });

  testWidgets('vazgeçme: recorder.cancel çağrılır, ekran başa döner', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('record-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-cancel')));
    await tester.pumpAndSettle();

    expect(recorder.cancelled, isTrue);
    expect(find.byKey(const Key('record-start')), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('kütüphane doluysa kayıt EKLENMEZ ve sebep söylenir', (
    tester,
  ) async {
    await pump(
      tester,
      adoptResult: const LocalSoundImportRejected(
        LocalSoundImportFailure.libraryFull,
        sizeBytes: 1,
        usedBytes: 2,
      ),
    );

    await tester.tap(find.byKey(const Key('record-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-error')), findsOneWidget);
    // Ekran adlandırma adımında KALIR: kullanıcı yer açıp tekrar deneyebilsin.
    expect(find.byKey(const Key('record-save')), findsOneWidget);
  });
}
