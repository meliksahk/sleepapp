import '../../core/audio_engine/dsp/mix_render.dart';
import '../content/content_models.dart';
// `show`: content_models.dart da `MixerState` adını taşıyor (preset mixer state)
// ve mixer_controller.dart'ınki UI durumu. İkisini birden çekmek adı belirsizleştirir.
import 'mixer_controller.dart' show defaultMixSpec;

/// Soundscape detayı → mikserin ÇALABİLECEĞİ tarif.
///
/// **NEDEN VAR:** `Soundscape.mixSpec` ayrıştırılıyordu, `Preset.toMixSpec()` vardı,
/// `MixerController` spec parametresi alıyordu — ama hiçbiri birbirine bağlı değildi.
/// Kütüphanedeki ses tıklanınca SES ÇIKMIYORDU. Burası o tel.

/// Çözümün sonucu: hangi tarif ve bu tarif gerçekten sesin kendi tarifi mi.
class ResolvedMix {
  const ResolvedMix({required this.spec, required this.usedFallback});

  final MixSpec spec;

  /// true → sesin kendi tarifi çözülemedi, varsayılan mix çalıyor.
  /// UI bunu kullanıcıya nazikçe söyler; ses YİNE DE çalar (offline-first).
  final bool usedFallback;
}

/// Çalma yolunda izin verilen toplam kazanç.
///
/// `MixPlayer` katmanları AYRI player'larda çalar; toplama işletim sistemi
/// mikserinde olur ve `renderMix`'in kompresörü bu yolda DEVREDE DEĞİL. Yani
/// toplam 1.0'ı aşarsa kırpma OS seviyesinde olur — uyku uygulamasında bu,
/// kullanıcının kulağında cızırtı demektir.
const double maxPlaybackTotalGain = 1.0;

/// Toplam kazancı [maxPlaybackTotalGain]'e indirger, katmanların BİRBİRİNE
/// oranını koruyarak.
///
/// Sunucudaki tarif tek tek katmanlar için 0..1 doğruluyor ama TOPLAMI
/// doğrulamıyor: 3 katman × 1.0 = 3.0 geçerli bir tariftir ve kırpardı.
/// Katmanları tek tek kısmak yerine ölçekliyoruz — tarifin karakteri korunur.
MixSpec limitTotalGain(MixSpec spec) {
  final total = spec.layers.fold<double>(0, (sum, l) => sum + l.gain);
  if (total <= maxPlaybackTotalGain || total <= 0) return spec;
  final k = maxPlaybackTotalGain / total;
  return MixSpec([
    for (final l in spec.layers)
      MixLayer(id: l.id, type: l.type, gain: l.gain * k),
  ]);
}

/// [detail]'dan çalınabilir tarifi çıkarır. **Asla null dönmez.**
///
/// Sıra:
/// 1. Sesin kendi tarifi (`soundscape.mixSpec`),
/// 2. yoksa ilk geçerli preset (`Preset.mixerState`) — tarif taslakta boş
///    bırakılmış ama preset yayınlanmış olabilir,
/// 3. o da yoksa [defaultMixSpec] + `usedFallback: true`.
///
/// 3. adım pazarlıksızdır (CLAUDE.md §3.1 "mikser internetsiz TAM çalışır"):
/// ağ yoksa, slug bilinmiyorsa ya da tarif bu sürümün tanımadığı şemadaysa
/// kullanıcı hata ekranı değil ÇALAN bir mikser görür.
ResolvedMix resolveSoundscapeMix(SoundscapeDetail? detail) {
  final spec = detail?.soundscape.mixSpec ?? _firstPresetSpec(detail);
  if (spec == null) {
    return ResolvedMix(spec: defaultMixSpec(), usedFallback: true);
  }
  return ResolvedMix(spec: limitTotalGain(spec), usedFallback: false);
}

MixSpec? _firstPresetSpec(SoundscapeDetail? detail) {
  for (final p in detail?.presets ?? const <Preset>[]) {
    final state = p.mixerState;
    if (state != null && state.layers.isNotEmpty) return state.toMixSpec();
  }
  return null;
}
