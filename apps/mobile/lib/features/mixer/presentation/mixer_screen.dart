import 'package:flutter/material.dart';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../l10n/app_localizations.dart';
import '../mixer_controller.dart';

/// Mikser ekranı (docs/04 M2) — **uygulamanın ses çıkardığı ilk yer.**
///
/// Slider'lar `setLayerGain`'e gider: yeniden render yok, ses kesilmez, değişim
/// anında duyulur.
class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key, this.controller});

  /// Test sahte controller enjekte edebilsin diye (cihazsız widget testi).
  final MixerController? controller;

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  late final MixerController _c;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? MixerController();
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

  String _layerLabel(AppL10n l10n, NoiseType type) {
    switch (type) {
      case NoiseType.white:
        return l10n.mixerLayerWhite;
      case NoiseType.pink:
        return l10n.mixerLayerPink;
      case NoiseType.brown:
        return l10n.mixerLayerBrown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = _c.state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mixerTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Dürüstlük: kullanıcı duyduğu şeyin nihai kalite olmadığını BİLMELİ.
            // Bunu saklamak, erken sürümde "ses kötü" izlenimini kalıcılaştırırdı.
            Text(
              l10n.mixerStopgapNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            if (s.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.mixerFailed,
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
                      label: l10n.mixerGainPercent(
                        ((s.gains[layer.id] ?? 0) * 100).round(),
                      ),
                      divisions: 20,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('mixer-toggle'),
              // Hazırlanırken buton KİLİTLİ: render sırasında ikinci kez basmak
              // ikinci bir render tetiklerdi.
              onPressed: s.isPreparing ? null : () => _c.toggle(),
              icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(
                s.isPreparing
                    ? l10n.mixerPreparing
                    : (s.isPlaying ? l10n.mixerPause : l10n.mixerPlay),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
