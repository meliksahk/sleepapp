import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/design_system/widgets/n_sound_texture.dart';
import 'package:nocta/features/content/content_models.dart';

MixSpec _spec(List<(LayerSource, double)> layers) => MixSpec([
  for (final (i, l) in layers.indexed) MixLayer(id: 'l$i', type: l.$1, gain: l.$2),
]);

void main() {
  group('doku SESTEN türer', () {
    test('baskın katman deseni seçer: her kaynak ayrı desen', () {
      final shapes = <SoundTextureShape>{
        for (final source in LayerSource.values) soundTextureSignature(_spec([(source, 0.8)]), 1).shape,
      };
      expect(
        shapes.length,
        LayerSource.values.length,
        reason: 'iki kaynak aynı deseni paylaşıyor: kütüphane yine tek tip görünür',
      );
    });

    test('baskın = en yüksek kazançlı katman, ikincil katman deseni değiştirmez', () {
      final rainDominant = soundTextureSignature(
        _spec([(LayerSource.pad, 0.2), (LayerSource.rain, 0.9)]),
        1,
      );
      expect(rainDominant.shape, SoundTextureShape.streak);
    });

    test('eşit kazançta enum sırası kazanır: aynı tarif her açılışta aynı yüz', () {
      final a = soundTextureSignature(
        _spec([(LayerSource.rain, 0.5), (LayerSource.white, 0.5)]),
        3,
      );
      final b = soundTextureSignature(
        _spec([(LayerSource.white, 0.5), (LayerSource.rain, 0.5)]),
        3,
      );
      expect(a.shape, b.shape);
      expect(a.shape, SoundTextureShape.speckle); // white, enum'da rain'den önce
    });

    test('sentez katmanı yoksa nötr tarama, çökme yok', () {
      expect(soundTextureSignature(null, 1).shape, SoundTextureShape.hatch);
      expect(soundTextureSignature(const MixSpec([]), 1).shape, SoundTextureShape.hatch);
    });

    test('yoğunluk katman sayısıyla artar, sınırlı kalır', () {
      final one = soundTextureSignature(_spec([(LayerSource.pink, 1)]), 1);
      final many = soundTextureSignature(
        _spec([for (final s in LayerSource.values) (s, 0.5)]),
        1,
      );
      expect(one.density, lessThan(many.density));
      expect(many.density, lessThanOrEqualTo(8));
    });

    test("kayma slug seed'inden: aynı desendeki iki tarif üst üste binmez", () {
      final a = soundTextureSignature(_spec([(LayerSource.pink, 1)]), 'a'.hashCode);
      final b = soundTextureSignature(_spec([(LayerSource.pink, 1)]), 'b'.hashCode);
      expect(a.phase, isNot(b.phase));
    });

    test('GERÇEK kütüphane: her tarif ayrıştırılır ve kareler tek tip değil', () {
      // Regresyon: eski boyacı slug hash'inden yalnız iki varyant (çapraz ya
      // da dikey tarama) üretiyordu; gömülü tarifler aynı kare görünüyordu.
      // Tarif ayrıştırılamasaydı da hepsi sessizce nötr taramaya düşerdi.
      final json = jsonDecode(File('assets/content/library.json').readAsStringSync()) as Map<String, dynamic>;
      final soundscapes = [
        for (final e in json['soundscapes'] as List<dynamic>)
          Soundscape.fromJson((e as Map<String, dynamic>)['soundscape'] as Map<String, dynamic>),
      ];
      expect(soundscapes, isNotEmpty);
      for (final s in soundscapes) {
        expect(s.mixSpec?.layers, isNotEmpty, reason: '${s.slug} tarifi ayrıştırılamadı');
      }
      final shapes = {for (final s in soundscapes) soundTextureSignature(s.mixSpec, s.slug.hashCode).shape};
      // Bugün 25 tarifte 10 ayrı desen var. Alt sınır içerik değişikliğine pay
      // bırakır; tek tipe dönüşü yakalamak için yeterli.
      expect(shapes.length, greaterThanOrEqualTo(5));
    });
  });

  group('boyacı', () {
    test('KIRPMA: her desen kutuyla sınırlanır ve bir şey çizer', () {
      // CustomPaint kırpmaz; kırpmayı boyacı yapmalı. Boş kare de hatadır.
      for (final shape in SoundTextureShape.values) {
        for (final density in [4, 8]) {
          final canvas = _SpyCanvas();
          SoundTexturePainter(
            SoundTextureSignature(shape: shape, density: density, phase: 0.3),
          ).paint(canvas, const Size(40, 40));

          expect(
            canvas.clipped,
            const Rect.fromLTWH(0, 0, 40, 40),
            reason: '$shape kırpılmıyor: desen kutunun dışına taşar',
          );
          expect(canvas.drawCalls, greaterThan(0), reason: '$shape/$density hiçbir şey çizmiyor');
        }
      }
    });
  });
}

/// Canvas'ın tamamını taklit etmek yerine çağrıları kaydeder (noSuchMethod).
class _SpyCanvas implements Canvas {
  Rect? clipped;
  int drawCalls = 0;

  @override
  void clipRect(Rect rect, {ClipOp clipOp = ClipOp.intersect, bool doAntiAlias = true}) {
    clipped = rect;
  }

  @override
  Object? noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) drawCalls++;
    return null;
  }
}
