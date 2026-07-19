import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';

/// **PROD APK AĞA ÇIKMIYOR** — sızıntı kapatma anahtarının sözleşmesi.
///
/// ## Neden bu test var (CLAUDE.md §6)
///
/// `main_prod.dart` `https://api.nocta.app`, `main_staging.dart`
/// `https://api-staging.nocta.app` adresine bakıyordu. Bu alan BİZİM DEĞİL —
/// DNS doğrulandı: `nocta.app` A kaydı Vercel'e gidiyor, `api.nocta.app` ise
/// SAHİPSİZ bir herokudns CNAME'ine. Yani kurulan prod APK, cihaz parmak izini
/// ve anonim oturum token'larını üçüncü bir tarafın istediği an DEVRALABİLECEĞİ
/// bir hosta yolluyordu.
///
/// Alan adını seçmek kullanıcının kararı; sızıntıyı durdurmak bizim işimiz.
/// Adres yapılandırılmadıkça ağ katmanı komple kapalı.
///
/// İddia SAYARAK kanıtlanıyor: sahte `http.Client` her çağrıyı sayıyor ve prod
/// yolunda sayaç SIFIR kalmalı.
void main() {
  group('ağ kapalı flavor (apiBaseUrl boş)', () {
    test('PROD ve STAGING girişleri ağ katmanını KAPALI bırakır', () {
      // Girişlerin kendisi (`main_prod.dart`/`main_staging.dart`) `void main()`
      // olduğu için doğrudan çağrılamaz; sözleşme dosya içeriğinden okunur.
      const prodSource = 'apps/mobile/lib/main_prod.dart';
      const stagingSource = 'apps/mobile/lib/main_staging.dart';
      for (final path in <String>['lib/main_prod.dart', 'lib/main_staging.dart']) {
        // YORUMLAR ELENİR: dosyalar sızıntının TARİHİNİ anlatıyor ve o anlatı
        // içinde alan adı geçiyor — asıl mesele KODUN ne yaptığı.
        final code = _read(path)
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('///'))
            .join('\n');

        expect(
          code,
          contains("apiBaseUrl: ''"),
          reason: '$path ağ katmanını açık bırakıyor ($prodSource/$stagingSource).',
        );
        expect(
          code,
          isNot(contains('nocta.app')),
          reason: '$path hâlâ sahip OLMADIĞIMIZ bir alana işaret ediyor.',
        );
      }
    });

    test('ÇEKİRDEK: istemci hiçbir çağrı yapmaz (sayaç SIFIR)', () async {
      final spy = _CountingClient();
      final client = NoctaApiClient(baseUrl: '', client: spy);

      expect(client.isEnabled, isFalse);

      // Uygulamanın gerçekten kullandığı her yol.
      final responses = <http.Response>[
        await client.getAuthed('/v1/content/feed', 'token'),
        await client.postAuthed('/v1/analytics/events', 'token', <String, Object>{}),
        await client.patchAuthed('/v1/me/profile', 'token', <String, Object>{}),
      ];

      for (final res in responses) {
        expect(res.statusCode, NoctaApiClient.serviceUnavailableStatus);
      }
      expect(
        spy.calls,
        0,
        reason: 'ağ kapalıyken TEK BİR istek bile oluşturulmamalı — '
            'sızıntı tam olarak buradan olurdu.',
      );
    });

    test('cihaz kaydı ve refresh de ağa çıkmaz', () async {
      final spy = _CountingClient();
      final client = NoctaApiClient(baseUrl: '', client: spy);

      // Bunlar CİHAZ PARMAK İZİ ve TOKEN taşıyan uçlar — sızıntının asıl bedeli.
      await expectLater(
        client.registerDevice(fingerprint: 'cihaz-123', platform: 'flutter'),
        throwsA(isA<Object>()),
      );
      await expectLater(client.refresh('gizli-refresh-token'), throwsA(isA<Object>()));

      expect(spy.calls, 0, reason: 'parmak izi/token taşıyan uç ağa çıktı');
    });

    test('açılış oturumu SESSİZCE başarır (kalıcı çevrimdışı bandı yok)', () async {
      final spy = _CountingClient();
      final auth = AuthController(
        NoctaApiClient(baseUrl: '', client: spy),
        InMemorySessionStore(),
      );

      // Hata FIRLATMAMALI: fırlatsaydı açılış akışı başarısız sayılır ve
      // kullanıcı hiçbir işe yaramayan bir "yeniden dene" düğmesine bakardı.
      await auth.ensureSession('cihaz-123');

      expect(auth.isAuthenticated, isFalse);
      expect(spy.calls, 0);
    });

    test('yetkili istek oturum yokken PATLAMAZ, 503 döner', () async {
      final spy = _CountingClient();
      final auth = AuthController(
        NoctaApiClient(baseUrl: '', client: spy),
        InMemorySessionStore(),
      );

      final res = await auth.authorizedRequest((token) async => http.Response('', 200));

      expect(res.statusCode, NoctaApiClient.serviceUnavailableStatus);
      expect(spy.calls, 0);
    });
  });

  group('DEV flavor ETKİLENMEZ', () {
    test('lokal API yapılandırıldığında istemci ağa ÇIKAR', () async {
      final spy = _CountingClient();
      final client = NoctaApiClient(baseUrl: 'http://localhost:3001', client: spy);

      expect(client.isEnabled, isTrue);

      final res = await client.getAuthed('/v1/content/feed', 'token');

      expect(res.statusCode, 200);
      expect(spy.calls, 1, reason: 'dev akışı bozuldu — lokal geliştirme çalışmaz');
      expect(spy.lastUrl, 'http://localhost:3001/v1/content/feed');
    });

    test('FlavorConfig.hasApi adres varlığını doğru raporlar', () {
      expect(
        const FlavorConfig(flavor: Flavor.dev, name: 'DEV', apiBaseUrl: 'http://x')
            .hasApi,
        isTrue,
      );
      expect(
        const FlavorConfig(flavor: Flavor.prod, name: 'PROD', apiBaseUrl: '').hasApi,
        isFalse,
      );
    });
  });
}

/// Testler `apps/mobile` dizininden koşuyor.
String _read(String path) => File(path).readAsStringSync();

/// Her çağrıyı SAYAN sahte istemci. `NoctaApiClient` ağ kapalıyken bunu HİÇ
/// çağırmamalı — testin tüm iddiası bu sayaç.
class _CountingClient extends http.BaseClient {
  int calls = 0;
  String? lastUrl;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastUrl = request.url.toString();
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}
