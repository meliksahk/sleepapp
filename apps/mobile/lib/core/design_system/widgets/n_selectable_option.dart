import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';
import 'n_paper.dart';

/// Tek seçimli soru seçeneği — **"seçili" hali gözle anlaşılmalı**.
///
/// **Neden var:** arketip testinde seçenekler tam genişlik `NButton` yığınıydı;
/// seçili olan yalnızca dolgu rengiyle ayrışıyordu ve ekran ana ekranda denetlenip
/// kaldırılan "dev menüsü" desenine dönüyordu. Bir seçim kontrolü buton değildir:
/// durum taşır, o durumu tek renkle değil **işaretle** anlatır.
///
/// **Elegy:** seçenek artık koyu bir kutu değil, tuvale yapıştırılmış **yırtık
/// krem kağıt**. Seçili hal renkle DEĞİL, sol kenardaki kızıl blok + kalın
/// çerçeve + kalın metinle anlatılır — kızıl zemin üstünde koyu metnin kontrastı
/// 4.5:1'i geçmiyor, o yüzden dolgu değil işaret kullanıldı.
///
/// - Dokunma hedefi ≥ 60px (CLAUDE.md §7 eşiği 44px).
/// - Etiket çok satırlı olabilir (TR metinleri EN'den uzun) — `Expanded` + sarma.
/// - Metin çağırandan gelir (i18n); bileşen dizge tutmaz.
class NSelectableOption extends StatelessWidget {
  const NSelectableOption({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.seed = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Yırtık kenarın tohumu — listede her seçenek farklı yırtılsın diye.
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: NPaper(
          seed: seed,
          padding: EdgeInsets.zero,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? NoctaColors.accentAurora : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: <Widget>[
                // Seçim işareti: şekil değişir (ince çizgi → kalın kızıl blok),
                // yalnızca renk değil.
                Container(
                  key: const Key('n-option-mark'),
                  width: selected ? 8 : 3,
                  height: selected ? 44 : 20,
                  margin: const EdgeInsets.only(left: NoctaSpace.s4),
                  color: selected ? NoctaColors.accentAurora : NoctaColors.inkOnPaperSoft,
                ),
                const SizedBox(width: NoctaSpace.s4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s3),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: NoctaFontSize.body,
                        height: 1.35,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: NoctaColors.inkOnPaper,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NoctaSpace.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
