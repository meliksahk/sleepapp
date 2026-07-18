import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';

/// # İSTEK ZAMAN AŞIMI — neden bu dosya var
///
/// İstemcide HİÇ timeout yoktu (`grep timeout lib/core/api/*.dart` → 0 sonuç).
/// Backend ayakta değilken — özellikle bağlantıyı REDDETMEYEN, sadece yanıt
/// VERMEYEN bir adreste (DNS'te A kaydı olmayan `api.nocta.app` bir kaptif portal
/// ardında tam olarak böyle davranır) — her istek işletim sisteminin varsayılanına
/// kadar, yani DAKİKALARCA asılı kalıyordu. Kullanıcının gördüğü şey donmuş bir
/// ekrandı.
///
/// Bu, ekran BAŞINA sarmalanmıştı (`mixer_route.dart`'ta 3 sn'lik bütçe) —
/// semptomun sarılması. Kök burada.
///
/// **`fakeAsync` kullanılıyor:** gerçek 5 saniye beklemek test paketine 5 saniye
/// eklerdi ve bir gün "yavaş test" diye silinirdi. Sahte zaman, saniyeleri
/// mikrosaniyede ilerletir ve iddiayı KESİN kılar (≈5 değil, tam 5).

/// Asla yanıt vermeyen sunucu.
http.Client _blackHole() => MockClient((req) => Completer<http.Response>().future);

/// İsteği başlatır ve hatasını bir kutuya yazar (Future beklenmez — sahte zaman
/// içinde `elapse` ile ilerletilecek).
List<Object?> _capture(Future<Object?> request) {
  final box = <Object?>[null];
  unawaited(() async {
    try {
      await request;
    } catch (e) {
      box[0] = e;
    }
  }());
  return box;
}

void main() {
  test('varsayılan timeout 5 saniye', () {
    expect(NoctaApiClient.defaultTimeout, const Duration(seconds: 5));
    expect(NoctaApiClient(baseUrl: 'http://x', client: _blackHole()).timeout,
        const Duration(seconds: 5));
  });

  test('yanıt vermeyen sunucuda GET sonsuza kadar beklemez — timeout\'ta düşer',
      () {
    fakeAsync((async) {
      final client = NoctaApiClient(baseUrl: 'http://x', client: _blackHole());
      final error = _capture(client.getAuthed('/v1/archetype/questions', 'token'));

      // Süre dolmadan HENÜZ düşmemeli (timeout'un erken tetiklenmediği kanıtı).
      async.elapse(const Duration(seconds: 4, milliseconds: 900));
      async.flushMicrotasks();
      expect(error[0], isNull, reason: 'sağlıklı ama yavaş istek kesilmemeli');

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(error[0], isA<TimeoutException>());
    });
  });

  test('POST/PATCH/refresh/registerDevice de timeout\'a tabi', () {
    final calls = <String, Future<Object?> Function(NoctaApiClient)>{
      'postAuthed': (c) => c.postAuthed('/p', 't', const <String, String>{}),
      'patchAuthed': (c) => c.patchAuthed('/p', 't', const <String, String>{}),
      'refresh': (c) => c.refresh('r'),
      'registerDevice': (c) =>
          c.registerDevice(fingerprint: 'f', platform: 'flutter'),
    };

    for (final entry in calls.entries) {
      fakeAsync((async) {
        final client = NoctaApiClient(baseUrl: 'http://x', client: _blackHole());
        final error = _capture(entry.value(client));

        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(error[0], isA<TimeoutException>(),
            reason: '${entry.key} timeout uygulamıyor');
      });
    }
  });

  test('timeout yapılandırılabilir (test/özel akışlar için)', () {
    fakeAsync((async) {
      final client = NoctaApiClient(
        baseUrl: 'http://x',
        client: _blackHole(),
        timeout: const Duration(milliseconds: 200),
      );
      final error = _capture(client.getAuthed('/p', 't'));

      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();
      expect(error[0], isA<TimeoutException>());
    });
  });
}
