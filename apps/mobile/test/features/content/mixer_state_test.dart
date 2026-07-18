import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';
import 'package:nocta/features/content/content_models.dart';

/// Sunucunun #99'da doğruladığı gövdenin BİREBİR aynısı (content e2e seed'i).
/// İki uç bu şekli paylaşır; burası sözleşmenin istemci tarafındaki kilidi.
const _serverJson = <String, dynamic>{
  'layers': [
    {'id': 'rain', 'type': 'pink', 'gain': 0.7},
    {'id': 'deep', 'type': 'brown', 'gain': 0.3},
  ],
};

void main() {
  group('MixerState.tryParse — sunucu sözleşmesi', () {
    test('sunucunun gönderdiği gövde ayrıştırılır', () {
      final s = MixerState.tryParse(_serverJson);
      expect(s, isNotNull);
      expect(s!.layers, hasLength(2));
      expect(s.layers[0].id, 'rain');
      expect(s.layers[0].type, LayerSource.pink);
      expect(s.layers[0].gain, 0.7);
      expect(s.layers[1].type, LayerSource.brown);
    });

    test('int kazanç (JSON 0/1) double’a çevrilir', () {
      final s = MixerState.tryParse(<String, dynamic>{
        'layers': [
          {'id': 'a', 'type': 'white', 'gain': 1},
        ],
      });
      expect(s?.layers.first.gain, 1.0);
    });

    test('Preset.fromJson tipli mixerState üretir (dynamic yok)', () {
      final p = Preset.fromJson(<String, dynamic>{
        'archetypeSlug': 'overthinker',
        'mixerState': _serverJson,
      });
      expect(p.mixerState, isNotNull);
      expect(p.mixerState!.layers, hasLength(2));
    });

    group('savunmacı ayrıştırma: geçersizse null (kısmi mix YOK)', () {
      final cases = <String, Object?>{
        'null': null,
        'liste': <dynamic>[],
        'layers yok': <String, dynamic>{},
        'boş layers': <String, dynamic>{'layers': <dynamic>[]},
        'eski {rain:0.7} biçimi': <String, dynamic>{'rain': 0.7},
        'bilinmeyen tip': <String, dynamic>{
          'layers': [
            {'id': 'a', 'type': 'purple', 'gain': 0.5},
          ],
        },
        'gain > 1': <String, dynamic>{
          'layers': [
            {'id': 'a', 'type': 'white', 'gain': 1.5},
          ],
        },
        'gain negatif': <String, dynamic>{
          'layers': [
            {'id': 'a', 'type': 'white', 'gain': -0.1},
          ],
        },
        'gain string': <String, dynamic>{
          'layers': [
            {'id': 'a', 'type': 'white', 'gain': '0.5'},
          ],
        },
        'id boş': <String, dynamic>{
          'layers': [
            {'id': '', 'type': 'white', 'gain': 0.5},
          ],
        },
        'tekrar eden id': <String, dynamic>{
          'layers': [
            {'id': 'a', 'type': 'white', 'gain': 0.5},
            {'id': 'a', 'type': 'pink', 'gain': 0.5},
          ],
        },
        'tek katman bozuk → tümü reddedilir': <String, dynamic>{
          'layers': [
            {'id': 'ok', 'type': 'pink', 'gain': 0.5},
            {'id': 'bad', 'type': 'nope', 'gain': 0.5},
          ],
        },
      };

      cases.forEach((name, input) {
        test('$name → null', () => expect(MixerState.tryParse(input), isNull));
      });
    });

    test('bozuk mixerState’li preset null taşır (çökmez)', () {
      final p = Preset.fromJson(<String, dynamic>{
        'archetypeSlug': 'x',
        'mixerState': <String, dynamic>{'rain': 0.7}, // eski biçim
      });
      expect(p.mixerState, isNull);
    });
  });

  group('toMixSpec — içerik→motor zinciri', () {
    test('katmanlar MixSpec’e birebir çevrilir', () {
      final spec = MixerState.tryParse(_serverJson)!.toMixSpec();
      expect(spec.layers, hasLength(2));
      expect(spec.layers[0].id, 'rain');
      expect(spec.layers[0].type, LayerSource.pink);
      expect(spec.layers[0].gain, 0.7);
    });

    test('sunucu preset’i gerçekten render edilebilir (uçtan uca)', () {
      final spec = MixerState.tryParse(_serverJson)!.toMixSpec();
      final audio = renderMix(spec, seconds: 1, seed: 42);

      expect(audio, hasLength(48000));
      expect(rms(audio), greaterThan(0.0)); // sessizlik değil
      expect(audio.every((s) => s.abs() <= 1.0), isTrue); // kırpma yok
      // DC BURADA İDDİA EDİLMEZ (bilerek): pencere ortalaması kısa pencerede
      // gürültülü bir istatistiktir — ölçüm 1sn'de 0.0086, 5sn'de 0.00002.
      // DC davranışı kendi ölçüldüğü pencerede dc_blocker_test/noise_golden_test
      // içinde sabitlenmiştir; burada tekrar etmek yanıltıcı olurdu.
    });
  });
}
