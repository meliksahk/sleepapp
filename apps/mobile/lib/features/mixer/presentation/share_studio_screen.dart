import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import 'mix_video_frame.dart';

/// **Share Studio** (Elegy §23) — mix-to-video'nun kendi ekranı.
///
/// **Neden var:** dışa aktarma KODU aylardır çalışıyordu (`MixVideoExporter`)
/// ama tek bir butonun arkasındaydı: kullanıcı ne çıkacağını görmeden, süresini
/// seçemeden basıyordu. Viral kanca #3'ün tamamı "paylaşmak hava atmak gibi
/// olsun" fikrine dayanıyor — ne çıkacağını görmeden paylaşılmaz.
///
/// **Süre seçenekleri 15/30/60 sn.** Tasarımda 10 dakika da vardı; 24 fps'te bu
/// 14 400 kare demek ve telefonda dakikalar sürer. Sunamayacağımız bir seçeneği
/// listelemek, kullanıcıyı bekleyip vazgeçmeye davet etmektir.
class ShareStudioScreen extends StatefulWidget {
  const ShareStudioScreen({
    super.key,
    required this.title,
    required this.peaks,
    required this.gradient,
    required this.exporting,
    required this.progress,
    required this.onExport,
  });

  final String title;

  /// Mix'in dalga formu özeti — önizleme ile üretilen video AYNI veriyi kullanır.
  final List<double> peaks;
  final LinearGradient gradient;

  final bool exporting;
  final double? progress;

  /// Seçilen süreyle dışa aktarmayı başlatır (paylaşım çağıranın işi).
  final void Function(int seconds) onExport;

  @override
  State<ShareStudioScreen> createState() => _ShareStudioScreenState();
}

class _ShareStudioScreenState extends State<ShareStudioScreen> {
  static const List<int> _lengths = <int>[15, 30, 60];
  int _seconds = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final double? progress = widget.progress;
    return Scaffold(
      appBar: AppBar(title: NMono(l10n.studioTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ÖNİZLEME: gerçek kare bileşeninin küçültülmüşü — ayrı bir
              // "temsilî" görsel çizseydik önizleme ile çıktı sessizce ayrışırdı.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: LayoutBuilder(
                      builder: (context, c) => FittedBox(
                        child: SizedBox(
                          width: 1080,
                          height: 1920,
                          child: MixVideoFrame(
                            key: const Key('studio-preview'),
                            title: widget.title,
                            peaks: widget.peaks,
                            progress: 0.35,
                            gradient: widget.gradient,
                            size: const Size(1080, 1920),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NoctaSpace.s5),
              NMono(l10n.studioLength, track: NoctaTrack.wide),
              const SizedBox(height: NoctaSpace.s3),
              Row(
                children: <Widget>[
                  for (final seconds in _lengths) ...<Widget>[
                    Expanded(
                      child: _LengthChip(
                        key: Key('studio-length-$seconds'),
                        label: l10n.studioSeconds(seconds),
                        selected: _seconds == seconds,
                        onTap: widget.exporting
                            ? null
                            : () => setState(() => _seconds = seconds),
                      ),
                    ),
                    if (seconds != _lengths.last)
                      const SizedBox(width: NoctaSpace.s2),
                  ],
                ],
              ),
              const SizedBox(height: NoctaSpace.s3),
              // Bekleme süresini SAKLAMA: her şey bu telefonda üretiliyor.
              Text(
                l10n.studioLengthHint,
                style: const TextStyle(
                  fontSize: NoctaFontSize.caption,
                  height: 1.6,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              if (widget.exporting) ...<Widget>[
                const SizedBox(height: NoctaSpace.s4),
                LinearProgressIndicator(
                  key: const Key('studio-progress'),
                  value: progress,
                  minHeight: 4,
                  backgroundColor: NoctaColors.bgOverlay,
                  color: NoctaColors.accentAurora,
                ),
              ],
              const SizedBox(height: NoctaSpace.s5),
              NButton(
                key: const Key('studio-export'),
                label: widget.exporting
                    ? l10n.mixerExporting(((progress ?? 0) * 100).round())
                    : l10n.studioExport,
                expand: true,
                rule: true,
                onPressed: widget.exporting
                    ? null
                    : () => widget.onExport(_seconds),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Süre çipi — Elegy'de yuvarlatma yok; seçim dolgu + kalın çerçeveyle anlatılır.
class _LengthChip extends StatelessWidget {
  const _LengthChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? NoctaColors.bgPaper : Colors.transparent,
            border: Border.all(
              color: selected ? NoctaColors.bgPaper : NoctaColors.lineStrong,
            ),
          ),
          child: NMono(
            label,
            color: selected ? NoctaColors.inkOnPaper : NoctaColors.inkSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}
