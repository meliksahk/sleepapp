import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/share/sharer.dart';
import '../../../l10n/app_localizations.dart';
import '../../archetype/archetype_gradient.dart';
import '../../archetype/archetype_providers.dart';
import '../mixer_controller.dart';

/// Mikser ekranı (docs/04 M2) — **uygulamanın ses çıkardığı ilk yer.**
///
/// Slider'lar `setLayerGain`'e gider: yeniden render yok, ses kesilmez, değişim
/// anında duyulur.
class MixerScreen extends ConsumerStatefulWidget {
  const MixerScreen({
    super.key,
    this.controller,
    this.sharer,
    this.canExportVideo,
    this.spec,
    this.recipeUnavailable = false,
    this.title,
  });

  /// AppBar başlığı — açılan sesin ADI.
  ///
  /// **Neden:** kullanıcı kütüphaneden belirli bir soundscape'e dokunup mikseri
  /// açıyordu ama başlık jenerik "Mikser" olarak kalıyordu; hangi sesin çaldığını
  /// söyleyen tek işaret yoktu. null → jenerik başlık (doğrudan `/mixer`, yani
  /// gerçekten bir ses seçilmemiş).
  final String? title;

  /// Test sahte controller enjekte edebilsin diye (cihazsız widget testi).
  final MixerController? controller;

  /// Çalınacak tarif — kütüphaneden gelen soundscape'in tarifi.
  ///
  /// `initState`'te BİR KEZ okunur ([controller] verilmişse hiç okunmaz): sonradan
  /// değişen bir spec, çalan sesi kesip yeniden render etmek anlamına gelirdi.
  /// null → [defaultMixSpec].
  final MixSpec? spec;

  /// Sesin kendi tarifi çözülemedi, varsayılanla açıldı — kullanıcıya söylenir.
  /// Ses YİNE DE çalar; bu bir hata ekranı değil, bir dipnottur.
  final bool recipeUnavailable;

  final Sharer? sharer;

  /// Video export'u bu platformda mümkün mü.
  ///
  /// **Varsayılan `Platform.isAndroid` DEĞİL, `defaultTargetPlatform`:** ilki testte
  /// host'u (Windows) görür ve butonu her zaman gizlerdi. Null → gerçek platform.
  final bool? canExportVideo;

  @override
  ConsumerState<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends ConsumerState<MixerScreen> {
  late final MixerController _c;
  late final Sharer _sharer = widget.sharer ?? PlatformSharer();

  /// iOS'ta native kodlayıcı YOK (D-13/D-14: `AVAssetWriter` Mac olmadan yazılamadı).
  /// Butonu göstermek, basınca `MissingPluginException` atan bir buton olurdu.
  bool get _canExportVideo =>
      widget.canExportVideo ?? defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? MixerController(spec: widget.spec);
    _c.onChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _c.onChanged = null;
    _c.dispose();
    super.dispose();
  }

  String _layerLabel(AppL10n l10n, LayerSource type) {
    switch (type) {
      case LayerSource.white:
        return l10n.mixerLayerWhite;
      case LayerSource.pink:
        return l10n.mixerLayerPink;
      case LayerSource.brown:
        return l10n.mixerLayerBrown;
      case LayerSource.waves:
        return l10n.mixerLayerWaves;
      case LayerSource.fire:
        return l10n.mixerLayerFire;
      case LayerSource.rain:
        return l10n.mixerLayerRain;
      case LayerSource.pad:
        return l10n.mixerLayerPad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = _c.state;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title?.isNotEmpty == true ? widget.title! : l10n.mixerTitle,
          key: const Key('mixer-title'),
        ),
      ),
      // **Kaydırılan liste + SABİT taşıma çubuğu (#213).** Önceden çal butonu
      // listenin sonundaydı; katman sayısı 3'ten 7'ye çıkınca ekranın ALTINA
      // düştü — kullanıcı sesi başlatmak için kaydırmak zorunda kalıyordu (ve
      // widget testleri bunu yakaladı: buton hiç inşa edilmiyordu). Taşıma
      // kontrolleri katman sayısından BAĞIMSIZ olarak erişilebilir olmalı.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Dürüstlük: kullanıcı duyduğu şeyin nihai kalite olmadığını BİLMELİ.
                  // Bunu saklamak, erken sürümde "ses kötü" izlenimini kalıcılaştırırdı.
                  Text(l10n.mixerStopgapNotice, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),

                  // Dürüstlük: kullanıcı istediği sesi seçti ama başka bir mix duyuyor.
                  // Bunu söylemek zorundayız — ama ses çalmaya devam eder (offline-first).
                  if (widget.recipeUnavailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        l10n.mixerRecipeUnavailable,
                        key: const Key('mixer-recipe-fallback'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  if (s.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        // Ses hatası mı export hatası mı — kullanıcıya doğru olanı söyle.
                        s.errorKind == MixerErrorKind.export
                            ? l10n.mixerExportFailed
                            : l10n.mixerFailed,
                        key: const Key('mixer-error'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),

                  for (final layer in s.layers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_layerLabel(l10n, layer.type)),
                          Slider(
                            key: Key('gain-${layer.id}'),
                            value: s.gains[layer.id] ?? 0,
                            onChanged: (v) => _c.setGain(layer.id, v),
                            // Erişilebilirlik: ekran okuyucu "pembe gürültü, %30" desin.
                            // Yüzde biçimi yerele bağlı (EN "30%", TR "%30") → i18n'den.
                            label: l10n.mixerGainPercent(((s.gains[layer.id] ?? 0) * 100).round()),
                            divisions: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── SABİT taşıma çubuğu: her zaman görünür ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('mixer-toggle'),
                      // Hazırlanırken buton KİLİTLİ: render sırasında ikinci kez
                      // basmak ikinci bir render tetiklerdi.
                      onPressed: s.isPreparing ? null : () => _c.toggle(),
                      icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(
                        s.isPreparing
                            ? l10n.mixerPreparing
                            : (s.isPlaying ? l10n.mixerPause : l10n.mixerPlay),
                      ),
                    ),
                  ),

                  // Viral kanca #3 (docs/04 §131). iOS'ta gizli: native kodlayıcı yok.
                  if (_canExportVideo) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('mixer-export-video'),
                        onPressed: s.isExporting ? null : _exportVideo,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: Text(
                          s.isExporting
                              ? l10n.mixerExporting((s.exportProgress! * 100).round())
                              : l10n.mixerExportVideo,
                        ),
                      ),
                    ),
                    if (s.isExporting)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(
                          key: const Key('mixer-export-progress'),
                          value: s.exportProgress,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportVideo() async {
    final l10n = AppL10n.of(context);
    // Viral kanca #3: export edilen video kullanıcının KENDİ arketip gradyanını
    // taşır (#178). Sonuç henüz yüklenmemişse/test yapılmamışsa slug null → nötr
    // varsayılan. `read` (watch değil): export tek seferlik bir eylem, o anki değer yeter.
    final slug = ref
        .read(latestArchetypeResultProvider)
        .maybeWhen(data: (r) => r?.archetypeSlug, orElse: () => null);
    final path = await _c.exportVideo(
      title: l10n.mixerVideoTitle,
      gradient: archetypeGradientForSlug(slug),
    );
    // Hata state'e yazıldı ve ekranda gösteriliyor; burada paylaşacak bir şey yok.
    if (path == null || !mounted) return;

    await _sharer.share(
      ShareContent(
        text: l10n.mixerExportShareText,
        url: 'https://nocta.app',
        file: ShareFile.mp4(path: path, filename: 'nocta-mix.mp4'),
      ),
    );
  }
}
