import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';

/// Tek seçimli soru seçeneği — **"seçili" hali gözle anlaşılmalı**.
///
/// **Neden var:** arketip testinde seçenekler tam genişlik `NButton` yığınıydı;
/// seçili olan yalnızca dolgu rengiyle ayrışıyordu ve ekran ana ekranda denetlenip
/// kaldırılan "dev menüsü" desenine dönüyordu. Bir seçim kontrolü buton değildir:
/// durum taşır, o durumu tek renkle değil **işaretle** (dolu daire + tik) anlatır.
///
/// `NButton`'un sade API'si bilinçli olarak bozulmadı — seçim durumu ayrı bir
/// bileşende yaşar.
///
/// - Dokunma hedefi ≥ 52px (CLAUDE.md §7 eşiği 44px).
/// - Etiket çok satırlı olabilir (TR metinleri EN'den uzun) — `Expanded` + sarma.
/// - Metin çağırandan gelir (i18n); bileşen dizge tutmaz.
class NSelectableOption extends StatelessWidget {
  const NSelectableOption({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(NoctaRadius.button);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? NoctaColors.accentAurora.withValues(alpha: 0.14)
            : NoctaColors.bgOverlay,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(
              horizontal: NoctaSpace.s4,
              vertical: NoctaSpace.s3,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? NoctaColors.accentAurora
                    : Colors.white.withValues(alpha: 0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _Mark(selected: selected),
                const SizedBox(width: NoctaSpace.s3),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? NoctaColors.inkPrimary
                          : NoctaColors.inkSecondary,
                    ),
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

/// Seçim işareti: boş halka → dolu daire + tik. Renk TEK başına taşıyıcı değil
/// (renk körlüğü / düşük kontrast ekran) — şekil de değişir.
class _Mark extends StatelessWidget {
  const _Mark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? NoctaColors.accentAurora : Colors.transparent,
        border: Border.all(
          color: selected ? NoctaColors.accentAurora : NoctaColors.inkFaint,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: NoctaColors.bgBase)
          : null,
    );
  }
}
