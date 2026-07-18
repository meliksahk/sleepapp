import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';

/// İstemcinin dil başlığını GERÇEKTEN gönderdiğini kanıtlar.
///
/// Bu testin varlık sebebi somut bir hata: arayüz Türkçeye çevrilmişti ama sunucudan
/// gelen arketip soruları İngilizce kalıyordu — çünkü hiçbir istek `Accept-Language`
/// göndermiyordu. Başlık sessizce düşerse test kırılır.
void main() {
  final capturedHeaders = <Map<String, String>>[];

  MockClient recorder(int status, String body) => MockClient((req) async {
        capturedHeaders.add(req.headers);
        return http.Response(body, status);
      });

  setUp(capturedHeaders.clear);

  const sessionBody =
      '{"userId":"u1","accessToken":"a","refreshToken":"r","accessTokenExpiresIn":900}';

  test('acceptLanguage verilince kimlik doğrulamalı GET başlığı taşır', () async {
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: recorder(200, '{}'),
      resolveLanguage: () => 'tr',
    );
    await client.getAuthed('/v1/archetype/questions', 'token123');

    expect(capturedHeaders.single['accept-language'], 'tr');
    // Dil başlığı auth başlığını EZMEMELİ.
    expect(capturedHeaders.single['authorization'], 'Bearer token123');
  });

  test('acceptLanguage null ise başlık HİÇ gönderilmez (sunucu varsayılanı geçerli)', () async {
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: recorder(200, '{}'),
    );
    await client.getAuthed('/v1/archetype/questions', 'token123');

    expect(capturedHeaders.single.containsKey('accept-language'), isFalse);
  });

  test('cihaz kaydı ve refresh de dil başlığı taşır (JSON header ezilmeden)', () async {
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: recorder(201, sessionBody),
      resolveLanguage: () => 'tr',
    );
    await client.registerDevice(fingerprint: 'fp-000001', platform: 'android');

    expect(capturedHeaders.single['accept-language'], 'tr');
    expect(capturedHeaders.single['content-type'], contains('application/json'));
  });

  test('POST gövdesi bozulmadan dil başlığı eklenir', () async {
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: MockClient((req) async {
        capturedHeaders.add(req.headers);
        expect(jsonDecode(req.body), {'version': 1});
        return http.Response('{}', 200);
      }),
      resolveLanguage: () => 'tr',
    );
    await client.postAuthed('/v1/archetype/answers', 'token123', {'version': 1});

    expect(capturedHeaders.single['accept-language'], 'tr');
  });

  /// REGRESYON KİLİDİ: dil İSTEK ANINDA çözülmeli.
  ///
  /// Dil sabit bir alan olduğunda `apiClientProvider` onu `watch` etmek zorundaydı;
  /// dil değişince provider yeniden kuruluyor, eski `http.Client` kapanıyor ve onu
  /// `read` ile tutan `AuthController` kapanmış client'la kalıyordu — dil değiştiren
  /// kullanıcının BÜTÜN istekleri ölüyordu. Bu test, tek bir client'ın dil değişimini
  /// yeniden yaratılmadan yansıttığını kanıtlar.
  test('dil DEĞİŞİRSE aynı client yeni dili gönderir (yeniden yaratma gerekmez)', () async {
    var current = 'en';
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: recorder(200, '{}'),
      resolveLanguage: () => current,
    );

    await client.getAuthed('/v1/archetype/questions', 't');
    expect(capturedHeaders.last['accept-language'], 'en');

    current = 'tr'; // kullanıcı ayarlardan dili değiştirdi
    await client.getAuthed('/v1/archetype/questions', 't');
    expect(capturedHeaders.last['accept-language'], 'tr');
  });

  test('resolver boş string dönerse başlık gönderilmez', () async {
    final client = NoctaApiClient(
      baseUrl: 'https://x.test',
      client: recorder(200, '{}'),
      resolveLanguage: () => '',
    );
    await client.getAuthed('/v1/x', 't');
    expect(capturedHeaders.single.containsKey('accept-language'), isFalse);
  });
}
