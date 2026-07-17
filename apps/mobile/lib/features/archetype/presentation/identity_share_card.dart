import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/card_renderer.dart';

/// Paylaşılabilir kimlik kartı — **viral kanca #1** (docs/04 §103).
///
/// 1080×1920 (Instagram story). Ekranda gösterilmek için değil, **görsele çevrilmek**
/// için çizilir: `RepaintBoundary` içinde, sabit boyutta, `MediaQuery`'den bağımsız.
///
/// **NEDEN SABİT BOYUT:** paylaşılan görsel her cihazda AYNI görünmeli. Ekran
/// boyutuna uyarlansaydı küçük telefonda sıkışık, tablette seyrek bir kart paylaşılırdı
/// — ve paylaşılan şey markanın kendisi.
///
/// **Metin ölçeklenmez** (`textScaler: noScaling`): kullanıcının sistem yazı boyutu
/// paylaşılan görseli bozmamalı. Erişilebilirlik ayarı EKRAN içindir, üretilen
/// artefakt için değil.
class IdentityShareCard extends StatelessWidget {
  const IdentityShareCard({
    super.key,
    required this.name,
    required this.tagline,
    required this.gradient,
  });

  final String name;
  final String? tagline;
  final LinearGradient gradient;

  /// Archetype slug → gradyan. Bilinmeyen slug'da aurora'ya düşer: yeni bir archetype
  /// eklendiğinde kart ÇÖKMEZ, yalnızca jenerik görünür.
  static LinearGradient gradientFor(String slug) {
    switch (slug) {
      case 'deep-ocean':
        return NoctaArchetypeGradient.deepOcean;
      case 'overthinker':
        return NoctaArchetypeGradient.overthinker;
      case 'delta-drifter':
        return NoctaArchetypeGradient.deltaDrifter;
      case 'dawn-chaser':
        return NoctaArchetypeGradient.dawnChaser;
      default:
        return NoctaArchetypeGradient.overthinker;
    }
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary YOK: kart artık ağaçta gizlenmiyor, `renderWidgetToPng`
    // kendi hattında kendi sınırını kuruyor (bkz. card_renderer.dart).
    return MediaQuery(
        // Sistem yazı boyutu paylaşılan artefaktı bozmasın.
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: shareCardSize.width,
            height: shareCardSize.height,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: gradient),
              child: Padding(
                padding: const EdgeInsets.all(96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      'MY SLEEP IDENTITY',
                      key: const Key('share-card-eyebrow'),
                      style: TextStyle(
                        fontSize: 36,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w500,
                        // Gradyan üzerinde: kırık beyaz, %70 — okunur ama başlığı ezmez.
                        color: NoctaColors.inkPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      name,
                      key: const Key('share-card-name'),
                      style: const TextStyle(
                        fontSize: 128,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                    if (tagline != null && tagline!.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      Text(
                        tagline!,
                        key: const Key('share-card-tagline'),
                        style: TextStyle(
                          fontSize: 48,
                          height: 1.35,
                          color: NoctaColors.inkPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Marka izi: paylaşılan her kart uygulamaya geri işaret etmeli —
                    // viral döngünün kapandığı yer burası.
                    Row(
                      children: [
                        Text(
                          'NOCTA',
                          key: const Key('share-card-wordmark'),
                          style: TextStyle(
                            fontSize: 44,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w500,
                            color: NoctaColors.inkPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'nocta.app',
                          style: TextStyle(
                            fontSize: 36,
                            color: NoctaColors.inkPrimary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}
