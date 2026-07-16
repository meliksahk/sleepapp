import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/sleep_tracking/db_envelope.dart';
import 'package:nocta/core/sleep_tracking/event_detector.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';

/// **ZİNCİRİN BİRLEŞTİĞİ YER:** sentetik mikrofon PCM → dB zarfı → olay tespiti →
/// oturum taslağı → API gövdesi.
///
/// Parçalar tek tek test edildi (#128 dedektör, #130 taslak) ama uçtan uca hiç
/// koşmamışlardı. Bu dosyanın derdi tam olarak "parçalar doğru ama birleşince
/// yanlış" hatası — bu oturumda cache (#122) ve refresh yarışında (#118) tam da
/// o sınıftan hatalar bulundu.
void main() {
  /// Verilen genlikte sinüs çerçevesi (sentetik mikrofon beslemesi).
  Float32List tone(double amp, {int n = 64}) {
    final f = Float32List(n);
    for (var i = 0; i < n; i++) {
      f[i] = amp * math.sin(2 * math.pi * i / 16);
    }
    return f;
  }

  /// API'nin gerçek yanıtı: `SleepSession.fromJson` bu alanların HEPSİNİ ister.
  /// (İlk yazımda eksik bıraktım ve test "Null is not int" ile patladı — sahte
  /// yanıt gerçeğe uymazsa test gerçeği değil kurgumu doğrular.)
  String sessionResponse({required String id, int minutes = 450}) => jsonEncode({
        'id': id,
        'nightDate': '2026-07-16',
        'startedAt': '2026-07-16T23:00:00.000Z',
        'endedAt': '2026-07-17T06:30:00.000Z',
        'durationMinutes': minutes,
        'movementEvents': 0,
        'soundEvents': 0,
      });

  /// Mevcut sleep_controller_test.dart ile AYNI kurulum (kopya değil, aynı desen:
  /// anonim cihaz kaydı → token → SleepController).
  Future<SleepController> build(Future<http.Response> Function(http.Request) handler) async {
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(
          jsonEncode({
            'accessToken': 'access-1',
            'refreshToken': 'r',
            'accessTokenExpiresIn': 900,
            'userId': 'u-1',
          }),
          201,
        );
      }
      return handler(req);
    });
    final api = NoctaApiClient(baseUrl: 'http://x', client: client);
    final auth = AuthController(api, InMemorySessionStore());
    await auth.registerAnonymously('fp');
    return SleepController(auth, api);
  }

  test('UÇTAN UCA: sentetik gece → API gövdesi (yalnızca türetilmiş sayılar)', () async {
    // 1) Sentetik gece: sessizlik + 3 kısa hareket + 1 uzun horlama.
    final detector = AcousticEventDetector(initialFloorDb: -60);
    void quiet(int n) {
      for (var i = 0; i < n; i++) {
        detector.addFrame(frameDbfs(tone(0.001)));
      }
    }

    void burst(double amp, int n) {
      for (var i = 0; i < n; i++) {
        detector.addFrame(frameDbfs(tone(amp)));
      }
    }

    quiet(60);
    for (var i = 0; i < 3; i++) {
      burst(0.2, 4); // kısa → hareket
      quiet(40); // refrakter geçsin
    }
    burst(0.3, 60); // uzun → ses
    quiet(30);
    detector.finish();

    // 2) Taslak
    final draft = buildSleepSession(
      events: detector.events,
      startedAt: DateTime.utc(2026, 7, 16, 23),
      endedAt: DateTime.utc(2026, 7, 17, 6, 30),
    );
    expect(draft.movementEvents, 3);
    expect(draft.soundEvents, 1);

    // 3) API'ye gönderim
    late Map<String, dynamic> body;
    final controller = await build((req) async {
      expect(req.url.path, '/v1/sleep/sessions');
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(sessionResponse(id: 's1'), 201);
    });
    final session = await controller.recordSession(draft);

    // 4) Gövde: yalnızca türetilmiş sayılar + UTC zaman (CLAUDE.md §4, §6).
    expect(body['movementEvents'], 3);
    expect(body['soundEvents'], 1);
    expect(body['startedAt'], '2026-07-16T23:00:00.000Z');
    expect(body.keys.toSet(), {'startedAt', 'endedAt', 'movementEvents', 'soundEvents'});
    expect(session.nightDate, '2026-07-16');
  });

  test('SESSİZ gece de gönderilir (0 olay geçerli bir gecedir)', () async {
    final detector = AcousticEventDetector(initialFloorDb: -60);
    for (var i = 0; i < 500; i++) {
      detector.addFrame(frameDbfs(tone(0.001)));
    }
    detector.finish();

    final draft = buildSleepSession(
      events: detector.events,
      startedAt: DateTime.utc(2026, 7, 16, 23),
      endedAt: DateTime.utc(2026, 7, 17, 7),
    );

    late Map<String, dynamic> body;
    final controller = await build((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(sessionResponse(id: 's2', minutes: 480), 201);
    });
    await controller.recordSession(draft);

    expect(body['movementEvents'], 0);
    expect(body['soundEvents'], 0);
  });

  test('HAM SES gövdeye ASLA sızmaz (CLAUDE.md §6 — mikrofon iznimizin gerekçesi)', () async {
    final detector = AcousticEventDetector(initialFloorDb: -60);
    for (var i = 0; i < 50; i++) {
      detector.addFrame(frameDbfs(tone(0.001)));
    }
    for (var i = 0; i < 5; i++) {
      detector.addFrame(frameDbfs(tone(0.5)));
    }
    detector.finish();

    final draft = buildSleepSession(
      events: detector.events,
      startedAt: DateTime.utc(2026, 7, 16, 23),
      endedAt: DateTime.utc(2026, 7, 17, 7),
    );

    late String raw;
    final controller = await build((req) async {
      raw = req.body;
      return http.Response(sessionResponse(id: 's3', minutes: 480), 201);
    });
    await controller.recordSession(draft);

    // Zarf, dB, olay detayı, çerçeve indeksi — hiçbiri gitmemeli.
    for (final leak in ['peakDb', 'floorDb', 'startFrame', 'durationFrames', 'dbfs']) {
      expect(raw, isNot(contains(leak)), reason: '$leak sızdı');
    }
  });
}
