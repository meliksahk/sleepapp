import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/archetype/archetype_service.dart';
import 'package:nocta/features/archetype/data/local_archetype_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'archetype_test_support.dart';

/// AĞ HİÇ YOKKEN tam akış + sunucu senkronunun sessizliği.
///
/// Bu dosyanın varlık sebebi: `api.nocta.app` ayakta değilken kurulan prod APK'da
/// arketip testi ÖLÜYDÜ. Aşağıdaki testler o senaryonun ta kendisi.

/// Sunucusuz servis — `remote: null`, yani hiçbir ağ yolu yok.
ArchetypeService _offline({LocalArchetypeStore? store}) => ArchetypeService(
      matrixSource: testMatrixSource(),
      store: store ?? InMemoryArchetypeStore(),
      now: () => DateTime.utc(2026, 7, 17, 22, 30),
    );

/// Her isteğe patlayan sunucu — "backend var ama bozuk/erişilemez".
Future<ArchetypeController> _brokenRemote({List<String>? seen}) async {
  final client = MockClient((req) async {
    seen?.add(req.url.path);
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
    throw http.ClientException('bağlantı yok', req.url);
  });
  final api = NoctaApiClient(baseUrl: 'http://ölü.example', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return ArchetypeController(auth, api);
}

Future<Map<String, String>> _allFirstOptions(ArchetypeService service) async {
  final m = await service.matrix();
  return <String, String>{
    for (final q in m.questions) q.id: q.options.first.id,
  };
}

void main() {
  group('ağ YOKKEN tam akış', () {
    test('sorular yüklenir (ağ isteği olmadan), her soru metinli ve seçenekli',
        () async {
      final service = _offline();
      final q = await service.questions('en');

      expect(q.version, greaterThan(0));
      expect(q.questions, hasLength(6));
      for (final question in q.questions) {
        expect(question.prompt, isNotEmpty);
        expect(question.options, hasLength(4));
        for (final o in question.options) {
          expect(o.label, isNotEmpty);
          expect(o.archetype, isNotEmpty);
        }
      }
    });

    test('sorular seçili dilde gelir', () async {
      final service = _offline();
      final en = await service.questions('en');
      final tr = await service.questions('tr');
      expect(tr.questions.first.prompt, isNot(en.questions.first.prompt));
      // Yapı aynı: aynı id'ler, aynı sıra (skorlama dilden bağımsız).
      expect(
        tr.questions.map((q) => q.id).toList(),
        en.questions.map((q) => q.id).toList(),
      );
    });

    test('cevaplar cihazda puanlanır ve sonuç DÖNER', () async {
      final service = _offline();
      final result = await service.submit(await _allFirstOptions(service));

      expect(result.archetypeSlug, 'deep-ocean');
      expect(result.scores['deep-ocean'], 6);
      expect(result.createdAt, '2026-07-17T22:30:00.000Z');
    });

    test('eksik cevap yerelde de reddedilir (sunucunun 400\'ünün karşılığı)',
        () async {
      final service = _offline();
      expect(
        () => service.submit(const <String, String>{'q1': 'q1a'}),
        throwsArgumentError,
      );
    });

    test('sonuç KALICI: yeni bir servis (uygulama yeniden açıldı) onu görür',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = PrefsArchetypeStore();

      final first = _offline(store: store);
      final saved = await first.submit(await _allFirstOptions(first));

      // Uygulama kapandı/açıldı: yeni servis, YENİ store nesnesi, aynı prefs.
      final second = _offline(store: PrefsArchetypeStore());
      final restored = await second.latest();

      expect(restored, isNotNull);
      expect(restored!.archetypeSlug, saved.archetypeSlug);
      expect(restored.scores['deep-ocean'], 6);
      expect(await second.history(), hasLength(1));
    });

    test('içerik (isim/tagline/özet) ağsız gelir, iki dilde de', () async {
      final service = _offline();
      final en = await service.content('en');
      final tr = await service.content('tr');

      expect(en.keys, hasLength(4));
      expect(en['deep-ocean']!.name, 'Deep Ocean');
      expect(en['deep-ocean']!.summary, isNotEmpty);
      expect(tr['deep-ocean']!.summary, isNot(en['deep-ocean']!.summary));
    });

    test('paylaşım verisi ağsız kurulur (viral kanca ağsız da çalışır)',
        () async {
      final service = _offline();
      await service.submit(await _allFirstOptions(service));

      final share = await service.share('en');
      expect(share, isNotNull);
      expect(share!.archetypeSlug, 'deep-ocean');
      expect(share.title, 'Deep Ocean');
      expect(share.webUrl, contains('/a/deep-ocean'));
      expect(share.deepLink, 'nocta://a/deep-ocean');
    });

    test('hiç test yapılmadıysa latest null, history boş', () async {
      final service = _offline();
      expect(await service.latest(), isNull);
      expect(await service.history(), isEmpty);
    });
  });

  group('sunucu senkronu SESSİZ', () {
    test('sunucu patlasa da submit başarılı döner ve sonuç yerelde durur',
        () async {
      final store = InMemoryArchetypeStore();
      final service = ArchetypeService(
        matrixSource: testMatrixSource(),
        store: store,
        remote: await _brokenRemote(),
      );

      final result = await service.submit(await _allFirstOptions(service));
      // Arka plan senkronunun BİTMESİNİ bekle — patlaması kullanıcıya
      // ulaşmadığını ancak gerçekten koştuktan sonra iddia edebiliriz.
      await service.pendingSync;

      expect(result.archetypeSlug, 'deep-ocean');
      expect(await store.latest(), isNotNull);
    });

    test('sunucu gerçekten DENENİR (sessizlik = hiç denememek değil)', () async {
      final seen = <String>[];
      final service = ArchetypeService(
        matrixSource: testMatrixSource(),
        store: InMemoryArchetypeStore(),
        remote: await _brokenRemote(seen: seen),
      );

      await service.submit(await _allFirstOptions(service));
      await service.pendingSync;

      expect(seen, contains('/v1/archetype/answers'));
    });

    test('latest/history: sunucu patlarsa hata FIRLATMAZ, boş döner', () async {
      final service = ArchetypeService(
        matrixSource: testMatrixSource(),
        store: InMemoryArchetypeStore(),
        remote: await _brokenRemote(),
      );

      expect(await service.latest(), isNull);
      expect(await service.history(), isEmpty);
    });

    test('yerelde sonuç varsa sunucuya HİÇ gidilmez', () async {
      final seen = <String>[];
      final store = InMemoryArchetypeStore();
      final service = ArchetypeService(
        matrixSource: testMatrixSource(),
        store: store,
        remote: await _brokenRemote(seen: seen),
      );
      await service.submit(await _allFirstOptions(service));
      await service.pendingSync;
      seen.clear();

      await service.latest();
      await service.history();

      expect(seen, isEmpty, reason: 'yerel kayıt varken ağa çıkmak boşuna bekletir');
    });
  });

  group('yerel depo', () {
    test('geçmiş yeniden eskiye sıralanır', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = PrefsArchetypeStore();
      final service = ArchetypeService(
        matrixSource: testMatrixSource(),
        store: store,
        now: () => DateTime.utc(2026, 7, 17),
      );

      final m = await service.matrix();
      await service.submit(<String, String>{
        for (final q in m.questions) q.id: q.options.first.id,
      });
      await service.submit(<String, String>{
        for (final q in m.questions) q.id: q.options.last.id,
      });

      final history = await store.history();
      expect(history, hasLength(2));
      expect(history.first.archetypeSlug, 'dawn-chaser'); // en yeni başta
      expect(history.last.archetypeSlug, 'deep-ocean');
    });

    test('bozuk kayıt uygulamayı patlatmaz — "geçmiş yok" sayılır', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrefsArchetypeStore.historyKey: '{bu json değil',
      });
      final store = PrefsArchetypeStore();

      expect(await store.history(), isEmpty);
      expect(await store.latest(), isNull);
    });
  });
}
