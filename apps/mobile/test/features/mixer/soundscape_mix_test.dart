import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/mixer/mixer_controller.dart' show defaultMixSpec;
import 'package:nocta/features/mixer/soundscape_mix.dart';

/// Soundscape → çalınabilir tarif çözümü.
///
/// Burada kanıtlanan iki şey: (1) kütüphanedeki ses GERÇEKTEN kendi tarifiyle
/// çalıyor, (2) tarif çözülemediğinde mikser SUSMUYOR — varsayılanla açılıyor.

SoundscapeDetail _detail({
  MixSpec? mixSpec,
  List<Preset> presets = const [],
}) => SoundscapeDetail(
  soundscape: Soundscape(
    id: 'id',
    slug: 'deep-ocean-hush',
    titleI18n: const {'en': 'Deep Ocean Hush'},
    archetypeAffinity: const [],
    version: 1,
    mixSpec: mixSpec,
  ),
  presets: presets,
  previewUrl: null,
);

void main() {
  test('sesin kendi tarifi kullanılır (id/tip/kazanç birebir)', () {
    const spec = MixSpec([
      MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.5),
      MixLayer(id: 'surf', type: LayerSource.pink, gain: 0.25),
    ]);

    final r = resolveSoundscapeMix(_detail(mixSpec: spec));

    expect(r.usedFallback, isFalse);
    expect(r.spec.layers.map((l) => l.id).toList(), ['deep', 'surf']);
    expect(r.spec.layers.map((l) => l.type).toList(), [
      LayerSource.brown,
      LayerSource.pink,
    ]);
    expect(r.spec.layers.map((l) => l.gain).toList(), [0.5, 0.25]);
  });

  test('tarif yoksa ilk GEÇERLİ preset kullanılır', () {
    final r = resolveSoundscapeMix(
      _detail(
        presets: [
          // Sunucu sözleşmesi tanınmadı → atlanır, çökmez.
          const Preset(archetypeSlug: 'a', mixerState: null),
          Preset(
            archetypeSlug: 'b',
            mixerState: MixerState.tryParse(const {
              'layers': [
                {'id': 'p1', 'type': 'white', 'gain': 0.3},
              ],
            }),
          ),
        ],
      ),
    );

    expect(r.usedFallback, isFalse);
    expect(r.spec.layers.single.id, 'p1');
    expect(r.spec.layers.single.type, LayerSource.white);
  });

  test('OFFLINE: detay null (ağ yok / bilinmeyen slug) → varsayılan tarif', () {
    final r = resolveSoundscapeMix(null);

    expect(r.usedFallback, isTrue);
    expect(
      r.spec.layers.map((l) => l.id).toList(),
      defaultMixSpec().layers.map((l) => l.id).toList(),
    );
  });

  test('mixSpec null + preset yok → varsayılan tarif (hata değil)', () {
    final r = resolveSoundscapeMix(_detail());
    expect(r.usedFallback, isTrue);
    expect(r.spec.layers, isNotEmpty);
  });

  test('SES GÜVENLİĞİ: toplam kazanç 1.0 üstündeyse ölçeklenir', () {
    // Sunucu katman başına 0..1 doğruluyor ama TOPLAMI doğrulamıyor.
    const loud = MixSpec([
      MixLayer(id: 'a', type: LayerSource.white, gain: 1.0),
      MixLayer(id: 'b', type: LayerSource.pink, gain: 1.0),
      MixLayer(id: 'c', type: LayerSource.brown, gain: 1.0),
    ]);

    final r = resolveSoundscapeMix(_detail(mixSpec: loud));
    final total = r.spec.layers.fold<double>(0, (s, l) => s + l.gain);

    expect(total, closeTo(1.0, 1e-9));
    // Ölçekleme oranları korur: eşit girenler eşit çıkar.
    expect(r.spec.layers.map((l) => l.gain).toSet().length, 1);
  });

  test('toplam 1.0 altındaysa tarife DOKUNULMAZ', () {
    const quiet = MixSpec([
      MixLayer(id: 'a', type: LayerSource.brown, gain: 0.2),
      MixLayer(id: 'b', type: LayerSource.pink, gain: 0.1),
    ]);
    final r = resolveSoundscapeMix(_detail(mixSpec: quiet));
    expect(r.spec.layers.map((l) => l.gain).toList(), [0.2, 0.1]);
  });

  test('varsayılan tarif de kırpma bütçesi içinde', () {
    final total = defaultMixSpec().layers.fold<double>(0, (s, l) => s + l.gain);
    expect(total, lessThanOrEqualTo(maxPlaybackTotalGain));
  });
}
