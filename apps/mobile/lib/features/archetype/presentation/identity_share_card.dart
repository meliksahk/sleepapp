import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/card_renderer.dart';
import '../archetype_gradient.dart';

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

  /// Archetype slug → gradyan. Tek kaynak `archetypeGradientForSlug` (#178); burada
  /// geriye-uyumlu ince sarmalayıcı olarak durur (mevcut çağıranlar kırılmasın).
  static LinearGradient gradientFor(String slug) =>
      archetypeGradientForSlug(slug);

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
          // ELEGY KOLAJI: kart artık baştan sona gradyan DEĞİL. Gece tuvali +
          // üstünde iki organik leke (krem kağıt + arketibin tenti) + serif ad.
          // Böylece paylaşılan görsel uygulamanın kendisiyle aynı dili konuşuyor
          // ve metin gradyanın açık ucunda kontrast kaybetmiyor (eski scrim'in
          // ölçülmemiş %28'i buradan tümden kalktı).
          child: ColoredBox(
            color: NoctaColors.bgBase,
            child: Stack(
              children: <Widget>[
                // LEKELERİN ALT SINIRI ~820: altındaki ad da krem, leke de krem.
                // İlk denemede ad tam kağıdın üstüne düşüyordu → krem üstü krem,
                // kontrast 1:1, ad GÖRÜNMÜYORDU. Golden'a bakmasaydım
                // "kontrast sorunu kalmadı" diye rapor edecektim.
                Positioned(
                  left: 90,
                  top: 150,
                  child: Container(
                    width: 430,
                    height: 430,
                    decoration: BoxDecoration(
                      color: NoctaColors.bgPaper,
                      borderRadius: BorderRadius.circular(NoctaRadius.full),
                    ),
                  ),
                ),
                Positioned(
                  left: 400,
                  top: 280,
                  child: Container(
                    width: 320,
                    height: 360,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(NoctaRadius.full),
                    ),
                  ),
                ),
                // Tanecik: basılı kağıt hissi, tüm kareyi kaplar.
                const Positioned.fill(child: NGrain(seed: 4, density: 5200)),
                Padding(
                  padding: const EdgeInsets.all(96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Esnek boşluk: metin bloğu ALTA yaslanır. Sabit bir
                      // boşluk denendi ve uzun ad/tagline'da 670px taştı
                      // (test yakaladı) — çözüm lekeleri yukarı almak oldu,
                      // metni aşağı zorlamak değil.
                      const Spacer(),
                      Text(
                        'MY SLEEP IDENTITY',
                        key: const Key('share-card-eyebrow'),
                        style: const TextStyle(
                          fontFamily: NoctaFont.mono,
                          fontSize: 34,
                          letterSpacing: 10,
                          color: NoctaColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        name,
                        key: const Key('share-card-name'),
                        style: const TextStyle(
                          fontFamily: NoctaFont.display,
                          fontSize: 132,
                          height: 1.02,
                          color: NoctaColors.inkPrimary,
                        ),
                      ),
                      if (tagline != null && tagline!.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        Text(
                          tagline!,
                          key: const Key('share-card-tagline'),
                          style: const TextStyle(
                            fontSize: 46,
                            height: 1.45,
                            color: NoctaColors.inkSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Marka izi: paylaşılan her kart uygulamaya geri işaret
                      // etmeli — viral döngünün kapandığı yer burası.
                      Row(
                        children: [
                          Text(
                            'NOCTA',
                            key: const Key('share-card-wordmark'),
                            style: const TextStyle(
                              fontFamily: NoctaFont.mono,
                              fontSize: 42,
                              letterSpacing: 12,
                              color: NoctaColors.inkPrimary,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'nocta.app',
                            style: TextStyle(
                              fontFamily: NoctaFont.mono,
                              fontSize: 34,
                              letterSpacing: 2,
                              color: NoctaColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
