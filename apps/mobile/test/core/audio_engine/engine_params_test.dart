import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/engine_params.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';

/// `engine_params` → [MixSpec] ayrıştırıcısı.
///
/// NEDEN: sunucu tarafında tarif zinciri kuruldu (admin yazıyor, feed taşıyor) ama
/// MOBİL `engineParams`'ı tamamen DÜŞÜRÜYORDU — tarif uygulamanın modeline hiç
/// ulaşmıyordu. Bu testler sözleşmenin iki tarafta AYNI olduğunu sabitler.
void main() {
  Object? decode(String json) => jsonDecode(json) as Object?;

  group('parseEngineParams — geçerli tarif', () {
    test('tek katman', () {
      final spec = parseEngineParams(
        decode('{"schemaVersion":1,"layers":[{"id":"base","type":"pink","gain":0.5}]}'),
      );
      expect(spec, isNotNull);
      expect(spec!.layers, hasLength(1));
      expect(spec.layers.first.id, 'base');
      expect(spec.layers.first.type, LayerSource.pink);
      expect(spec.layers.first.gain, 0.5);
    });

    test('üç kaynak türü de tanınır', () {
      final spec = parseEngineParams(decode(
        '{"schemaVersion":1,"layers":['
        '{"id":"a","type":"white","gain":0.1},'
        '{"id":"b","type":"pink","gain":0.2},'
        '{"id":"c","type":"brown","gain":0.3}]}',
      ));
      expect(spec!.layers.map((l) => l.type),
          [LayerSource.white, LayerSource.pink, LayerSource.brown]);
    });

    test('gain tam sayı gelebilir (JSON 1 ile 1.0 aynı şeydir)', () {
      // Sunucu hangisini yollayacağını garanti etmez; `is double` yazsaydık
      // gain:1 gelen tarif sessizce reddedilirdi.
      final spec = parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":1}]}'));
      expect(spec!.layers.first.gain, 1.0);
    });

    test('sınır değerler kabul: gain 0 ve 1', () {
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":0}]}')),
        isNotNull,
      );
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":1}]}')),
        isNotNull,
      );
    });

    test('8 katman kabul (üst sınır)', () {
      final layers = List.generate(
        8,
        (i) => '{"id":"l$i","type":"pink","gain":0.1}',
      ).join(',');
      expect(parseEngineParams(decode('{"schemaVersion":1,"layers":[$layers]}')), isNotNull);
    });

    test('render edilebilir: ayrıştırılan spec gerçekten SES ÜRETİR', () {
      // Ayrıştırmanın anlamı bu: sonuç motorun tükettiği şey olmalı.
      final spec = parseEngineParams(
        decode('{"schemaVersion":1,"layers":[{"id":"base","type":"pink","gain":0.5}]}'),
      )!;
      final out = renderMix(spec, seconds: 1, sampleRate: 128, seed: 1);
      expect(out, hasLength(128));
      expect(out.any((s) => s != 0), isTrue);
    });
  });

  group('parseEngineParams — ÇÖKMEZ, null döner (docs/04 §79)', () {
    test('BİLİNMEYEN ŞEMA SÜRÜMÜ → null (uygulama mağazada yıllarca yaşar)', () {
      // Bu testin sebebi docs/04 §79: "eski uygulama yeni şemayı görürse zarifçe
      // eski preset'e düşer (crash değil)". Atmak = kullanıcının kütüphanesi çöker.
      expect(
        parseEngineParams(decode('{"schemaVersion":2,"layers":[{"id":"a","type":"pink","gain":0.5}]}')),
        isNull,
      );
    });

    test('sürüm YOK → null (hangi kurallara göre okunacağı belirsiz)', () {
      expect(parseEngineParams(decode('{"layers":[{"id":"a","type":"pink","gain":0.5}]}')), isNull);
    });

    test('BİLİNMEYEN kaynak türü → TÜM tarif reddedilir', () {
      // "Yaklaşık" bir kaynakla değiştirmek YANLIŞ ses çalmak olurdu.
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"green","gain":0.5}]}')),
        isNull,
      );
    });

    test('bir katman bozuksa TAMAMI reddedilir (kısmi mix = duyulmayan hata)', () {
      expect(
        parseEngineParams(decode(
          '{"schemaVersion":1,"layers":['
          '{"id":"iyi","type":"pink","gain":0.5},'
          '{"id":"kotu","type":"pink","gain":9}]}',
        )),
        isNull,
      );
    });

    test('gain aralık dışı → null', () {
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":1.5}]}')),
        isNull,
      );
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":-0.1}]}')),
        isNull,
      );
    });

    test('gain sayı değil → null', () {
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"a","type":"pink","gain":"yuksek"}]}')),
        isNull,
      );
    });

    test('tekrarlı katman id → null (belirsiz mix)', () {
      expect(
        parseEngineParams(decode(
          '{"schemaVersion":1,"layers":['
          '{"id":"a","type":"pink","gain":0.3},'
          '{"id":"a","type":"brown","gain":0.3}]}',
        )),
        isNull,
      );
    });

    test('katman yok / boş liste → null', () {
      expect(parseEngineParams(decode('{"schemaVersion":1,"layers":[]}')), isNull);
      expect(parseEngineParams(decode('{"schemaVersion":1}')), isNull);
    });

    test('9 katman → null (CPU/headroom sınırı)', () {
      final layers = List.generate(9, (i) => '{"id":"l$i","type":"pink","gain":0.1}').join(',');
      expect(parseEngineParams(decode('{"schemaVersion":1,"layers":[$layers]}')), isNull);
    });

    test('boş tarif (taslağın doğduğu hâl) → null', () {
      expect(parseEngineParams(decode('{}')), isNull);
    });

    test('tarif hiç yok / yanlış tip → null', () {
      expect(parseEngineParams(null), isNull);
      expect(parseEngineParams('bu bir tarif degil'), isNull);
      expect(parseEngineParams(42), isNull);
      expect(parseEngineParams(decode('[]')), isNull);
    });

    test('id boş / eksik → null', () {
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"id":"","type":"pink","gain":0.5}]}')),
        isNull,
      );
      expect(
        parseEngineParams(decode('{"schemaVersion":1,"layers":[{"type":"pink","gain":0.5}]}')),
        isNull,
      );
    });
  });
}
