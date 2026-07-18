import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/share/sharer.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/analytics/analytics.dart';
import 'package:nocta/features/analytics/analytics_providers.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/archetype/archetype_gradient.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/archetype_service.dart';
import 'package:nocta/features/archetype/data/archetype_matrix_source.dart';
import 'package:nocta/features/archetype/data/local_archetype_store.dart';
import 'package:nocta/features/settings/locale_store.dart';
import 'package:nocta/features/archetype/presentation/archetype_test_screen.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/l10n/app_localizations.dart';

import 'archetype_test_support.dart';

/// Bu ekran artık **YEREL-ÖNCELİKLİ** (bkz. archetype_service.dart): sorular
/// gömülü matristen, puanlama cihazda, sonuç cihazdaki kayıttan gelir. Testler
/// bu yüzden sahte SORU JSON'u kurmaz — GERÇEK üretilmiş matrisi kullanır.
/// Sunucu yalnızca paylaşım verisi ve arka plan senkronu için mock'lanır.

class RecordingAnalytics implements Analytics {
  final List<String> events = [];
  Map<String, dynamic>? lastProps;
  @override
  void track(String name, {Map<String, dynamic>? props}) {
    events.add(name);
    lastProps = props;
  }

  @override
  Future<int> flush() async => 0;
}

class RecordingSharer implements Sharer {
  ShareContent? last;
  @override
  Future<void> share(ShareContent content) async => last = content;
}

/// Paylaşım ucunu karşılayan sunucu istemcisi (diğer uçlar bu ekranda
/// kullanılmıyor: sorular/puanlama/içerik cihazda).
Future<ArchetypeController> _remote() async {
  final client = MockClient((req) async {
    if (req.url.path == '/v1/auth/device') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    }
    if (req.url.path == '/v1/sharing/archetype') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'archetypeSlug': 'deep-ocean',
          'title': 'My sleep identity is Deep Ocean',
          'description': 'Take the NOCTA sleep ritual test to discover yours.',
          'webUrl': 'https://nocta.app/a/deep-ocean',
          'deepLink': 'nocta://a/deep-ocean',
        }),
        200,
      );
    }
    // Arka plan senkronu dahil diğer her şey 404 — kullanıcı bunu GÖRMEMELİ.
    return http.Response('not found', 404);
  });
  final api = NoctaApiClient(baseUrl: 'http://x', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return ArchetypeController(auth, api);
}

ArchetypeResult _saved(String slug) => ArchetypeResult(
      userId: '',
      archetypeSlug: slug,
      scores: <String, num>{slug: 4},
      version: 1,
      createdAt: '2026-07-16T00:00:00.000Z',
    );

Future<ArchetypeService> _service({
  bool existingResult = false,
  ArchetypeMatrixSource? matrixSource,
}) async {
  final store = InMemoryArchetypeStore();
  if (existingResult) await store.save(_saved('overthinker'));
  return ArchetypeService(
    matrixSource: matrixSource ?? testMatrixSource(),
    store: store,
    remote: await _remote(),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ArchetypeService service, {
  Sharer? sharer,
  RecordingAnalytics? analytics,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        archetypeServiceProvider.overrideWithValue(service),
        // Dil provider'ı testte SharedPreferences'a uzanır; çözülmeyen dil
        // soruları ve içeriği sonsuza dek loading'de bırakırdı.
        appLocaleProvider.overrideWith((ref) async => null),
        // Analytics override — default'u apiClientProvider→FlavorConfig okur (testte yok).
        analyticsProvider.overrideWithValue(analytics ?? RecordingAnalytics()),
        if (sharer != null) sharerProvider.overrideWithValue(sharer),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const ArchetypeTestScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Sihirbazdaki HER soruya `a` seçeneğini işaretler (hepsi deep-ocean).
Future<void> _answerAll(WidgetTester tester) async {
  for (var i = 1; i <= MatrixFixture.questionCount; i++) {
    final key = Key('opt-q$i-q${i}a');
    await tester.scrollUntilVisible(find.byKey(key), 120);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(const Key('archetype-submit')), 200);
  await tester.tap(find.byKey(const Key('archetype-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('soruları yükler, cevaplar, sonucu gösterir', (tester) async {
    await _pump(tester, await _service());

    // Sorular GÖMÜLÜ matristen geldi — ağ isteği yok.
    expect(find.text(MatrixFixture.firstPromptEn), findsOneWidget);
    expect(find.byKey(const Key('archetype-result')), findsNothing);

    // Hepsini cevaplamadan submit → hâlâ sonuç yok (gating).
    await _submit(tester);
    expect(find.byKey(const Key('archetype-result')), findsNothing);

    await _answerAll(tester);
    await _submit(tester);

    expect(find.byKey(const Key('archetype-result')), findsOneWidget);
    expect(find.text(MatrixFixture.allAnswersName), findsOneWidget);
    expect(find.byKey(const Key('archetype-tagline')), findsOneWidget);
    expect(find.text(MatrixFixture.allAnswersTagline), findsOneWidget);
  });

  testWidgets(
    'sonuç görüntülenince archetype_completed analitik olayı gönderilir',
    (tester) async {
      final analytics = RecordingAnalytics();
      await _pump(tester, await _service(), analytics: analytics);

      await _answerAll(tester);
      await _submit(tester);

      expect(analytics.events, contains('archetype_completed'));
      expect(analytics.lastProps?['archetype'], MatrixFixture.allAnswersArchetype);
    },
  );

  testWidgets(
    'sonuçta paylaş → sharer web URL alır, "Link copied" + share_tapped',
    (tester) async {
      final sharer = RecordingSharer();
      final analytics = RecordingAnalytics();
      await _pump(
        tester,
        await _service(),
        sharer: sharer,
        analytics: analytics,
      );

      await _answerAll(tester);
      await _submit(tester);

      await tester.tap(find.byKey(const Key('archetype-share')));

      // `runAsync` ŞART: paylaşım önce kimlik kartını PNG'ye render ediyor
      // (viral kanca #1) ve `toImage` motorun GERÇEK asenkron işi — sahte zaman
      // bölgesinde tamamlanmaz. `pumpAndSettle` tek başına yetmez ve iddia,
      // `share()` hiç çağrılmadan koşardı.
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();

      expect(sharer.last?.url, 'https://nocta.app/a/deep-ocean');
      expect(sharer.last?.text, contains('Deep Ocean'));
      // ÇEKİRDEK: link değil GÖRSEL paylaşılıyor (docs/04 §103).
      expect(sharer.last?.file, isNotNull, reason: 'kimlik kartı PNG olarak gitmeli');
      expect(sharer.last!.file!.bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47],
          reason: 'gerçek PNG olmalı');
      // MIME tipi veriyle gelmeli — kart PNG, gece zarfı CSV.
      expect(sharer.last!.file!.mimeType, 'image/png');
      expect(find.text('Link copied'), findsOneWidget);
      // Viral huni: sonuç görüldü + paylaşıldı.
      expect(
        analytics.events,
        containsAll(<String>['archetype_completed', 'share_tapped']),
      );
    },
  );

  testWidgets(
    'kayıtlı sonuç varsa doğrudan sonucu gösterir (sihirbaz atlanır)',
    (tester) async {
      await _pump(tester, await _service(existingResult: true));

      expect(find.byKey(const Key('archetype-result')), findsOneWidget);
      expect(find.text('3AM Overthinker'), findsOneWidget);
      // Sihirbaz gösterilmez (soru/submit yok).
      expect(find.byKey(const Key('archetype-submit')), findsNothing);
    },
  );

  testWidgets('Retake → sonuçtan sihirbaza döner', (tester) async {
    await _pump(tester, await _service(existingResult: true));
    expect(find.byKey(const Key('archetype-result')), findsOneWidget);

    await tester.tap(find.byKey(const Key('archetype-retake')));
    await tester.pumpAndSettle();

    // Sihirbaz göründü: soru + submit var, sonuç yok.
    expect(find.text(MatrixFixture.firstPromptEn), findsOneWidget);
    expect(find.byKey(const Key('archetype-submit')), findsOneWidget);
    expect(find.byKey(const Key('archetype-result')), findsNothing);
  });

  testWidgets('ilerleme göstergesi cevaplandıkça günceller', (tester) async {
    await _pump(tester, await _service());

    expect(find.text('0 of 6 answered'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opt-q1-q1a')));
    await tester.pumpAndSettle();

    expect(find.text('1 of 6 answered'), findsOneWidget);
    expect(find.text('0 of 6 answered'), findsNothing);
  });

  testWidgets('seçenek seçilince NSelectableOption seçili hale geçer', (
    tester,
  ) async {
    await _pump(tester, await _service());

    NSelectableOption option(String key) => tester.widget<NSelectableOption>(
      find.byKey(Key(key)),
    );

    expect(option('opt-q1-q1a').selected, isFalse);
    expect(option('opt-q1-q1b').selected, isFalse);

    await tester.tap(find.byKey(const Key('opt-q1-q1a')));
    await tester.pumpAndSettle();

    // Tek seçim: seçilen işaretlenir, diğeri boşalır.
    expect(option('opt-q1-q1a').selected, isTrue);
    expect(option('opt-q1-q1b').selected, isFalse);

    await tester.tap(find.byKey(const Key('opt-q1-q1b')));
    await tester.pumpAndSettle();

    expect(option('opt-q1-q1a').selected, isFalse);
    expect(option('opt-q1-q1b').selected, isTrue);
  });

  testWidgets(
    'ÇEKİRDEK: sonuç ekranı kullanıcının KENDİ arketip gradyanını gösterir',
    (tester) async {
      await _pump(tester, await _service());
      await _answerAll(tester);
      await _submit(tester);

      // Sonuç deep-ocean; ekranda o slug'ın gradyanı çizilmiş olmalı — kimlik
      // gradyanı ana ekranda ve paylaşılan PNG'de vardı, sonucun İLK görüldüğü
      // anda yoktu (#tasarım). Gradyan tek kaynaktan gelir (#178).
      final expected = archetypeGradientForSlug(MatrixFixture.allAnswersArchetype);
      final gradients = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>()
          .toList();

      expect(
        gradients.any((g) => g.colors.toString() == expected.colors.toString()),
        isTrue,
        reason: 'deep-ocean gradyanı sonuç ekranında çizilmeli',
      );
    },
  );

  testWidgets('sonuç ekranı kaydırılabilir (uzun metinde taşma yok)', (
    tester,
  ) async {
    // Küçük ekran + uzun içerik: eski Center+Column sessizce taşıyordu.
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, await _service(existingResult: true));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hata halinde NErrorState çıkar (çıplak refresh ikonu değil)', (
    tester,
  ) async {
    // Artık tek gerçek hata kaynağı: gömülü matris okunamadı (asset bozuk/eksik).
    await _pump(
      tester,
      await _service(matrixSource: brokenMatrixSource()),
    );

    expect(find.byType(NErrorState), findsOneWidget);
    expect(find.byKey(const Key('archetype-retry')), findsOneWidget);
    // Hata ekranı kullanıcıya NE olduğunu söylemeli.
    expect(
      find.text('Could not load this. Check your connection and try again.'),
      findsOneWidget,
    );
  });
}
